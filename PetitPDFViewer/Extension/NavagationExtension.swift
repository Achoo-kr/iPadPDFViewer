//
//  Navigation.swift
//  PetitPDFViewer
//
//  Created by 추현호 on 2023/06/17.
//

import ComposableArchitecture
import SwiftUI
import SwiftUINavigation

private struct DismissID: Hashable { let id: AnyHashable }

enum PresentationAction<Action> {
  case dismiss
  case presented(Action)
}
extension PresentationAction: Equatable where Action: Equatable {}

extension Reducer {
  func ifLet<ChildState: Identifiable, ChildAction>(
    _ stateKeyPath: WritableKeyPath<State, ChildState?>,
    action actionCasePath: CasePath<Action, PresentationAction<ChildAction>>
  ) -> some ReducerOf<Self>
  where ChildState: _EphemeralState
  {
    self.ifLet(stateKeyPath, action: actionCasePath) {
      EmptyReducer()
    }
  }

  func ifLet<ChildState: Identifiable, ChildAction>(
    _ stateKeyPath: WritableKeyPath<State, ChildState?>,
    action actionCasePath: CasePath<Action, PresentationAction<ChildAction>>,
    @ReducerBuilder<ChildState, ChildAction> child: () -> some Reducer<ChildState, ChildAction>
  ) -> some ReducerOf<Self> {
    let child = child()
    return Reduce { state, action in
      switch (state[keyPath: stateKeyPath], actionCasePath.extract(from: action)) {

      case (_, .none):
        let childStateBefore = state[keyPath: stateKeyPath]
        let effects = self.reduce(into: &state, action: action)
        let childStateAfter = state[keyPath: stateKeyPath]
        let cancelEffect: Effect<Action>
        if
          !(ChildState.self is _EphemeralState.Type),
          let childStateBefore,
          childStateBefore.id != childStateAfter?.id
        {
          cancelEffect = .cancel(id: childStateBefore.id)
        } else {
          cancelEffect = .none
        }
        let onFirstAppearEffect: Effect<Action>
        if
          !(ChildState.self is _EphemeralState.Type),
          let childStateAfter,
          childStateAfter.id != childStateBefore?.id
        {
          onFirstAppearEffect = .run { send in
            do {
              try await withTaskCancellation(id:  DismissID(id: childStateAfter.id)) {
                try await Task.never()
              }
            } catch is CancellationError {
              await send(actionCasePath.embed(.dismiss))
            }
          }
          .cancellable(id: childStateAfter.id)
        } else {
          onFirstAppearEffect = .none
        }
        return .merge(
          effects,
          cancelEffect,
          onFirstAppearEffect
        )

      case (.none, .some(.presented)), (.none, .some(.dismiss)):
        XCTFail("A presentation action was sent while child state was nil.")
        return self.reduce(into: &state, action: action)

      case (.some(var childState), .some(.presented(let childAction))):
        defer {
          if ChildState.self is _EphemeralState.Type {
            state[keyPath: stateKeyPath] = nil
          }
        }
        let childEffects = child
          .dependency(\.dismiss, DismissEffect { [id = childState.id] in
            Task.cancel(id:  DismissID(id: id))
          })
          .reduce(into: &childState, action: childAction)
        state[keyPath: stateKeyPath] = childState
        let effects = self.reduce(into: &state, action: action)
        return .merge(
          childEffects
            .map { actionCasePath.embed(.presented($0)) }
            .cancellable(id: childState.id),
          effects
        )

      case let (.some(childState), .some(.dismiss)):
        let effects = self.reduce(into: &state, action: action)
        state[keyPath: stateKeyPath] = nil
        return .merge(
          effects,
          .cancel(id: childState.id)
        )
      }
    }
  }
}


extension View {
    func sheet<ChildState: Identifiable, ChildAction>(
        store: Store<ChildState?, PresentationAction<ChildAction>>,
        @ViewBuilder child: @escaping (Store<ChildState, ChildAction>) -> some View
    ) -> some View {
        WithViewStore(store, observe: { $0?.id }) { viewStore in
            self.sheet(
                item: Binding(
                    get: { viewStore.state.map { Identified($0, id: \.self) } },
                    set: { newState in
                        if viewStore.state != nil {
                            viewStore.send(.dismiss)
                        }
                    }
                )
            ) { _ in
                IfLetStore(
                    store.scope(
                        state: returningLastNonNilValue { $0 },
                        action: PresentationAction.presented
                    )
                ) { store in
                    child(store)
                }
            }
        }
    }
}

func returningLastNonNilValue<A, B>(
  _ f: @escaping (A) -> B?
) -> (A) -> B? {
  var lastValue: B?
  return { a in
    lastValue = f(a) ?? lastValue
    return lastValue
  }
}

extension View {
  func alert<Action>(
    store: Store<AlertState<Action>?, PresentationAction<Action>>
  ) -> some View {
    WithViewStore(
      store,
      observe: { $0 },
      removeDuplicates: { ($0 != nil) == ($1 != nil) }
    ) { viewStore in
      self.alert(
        unwrapping: Binding(
          get: { viewStore.state },
          set: { newState in
            if viewStore.state != nil {
              viewStore.send(.dismiss)
            }
          }
        )
      ) { action in
        if let action {
          viewStore.send(.presented(action))
        }
      }
    }
  }
}
