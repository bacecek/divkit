import CommonCorePublic
import LayoutKit

public class DivStateManager {
  public struct Item: Equatable {
    public let currentStateID: DivStateID
    // Previous state is used for transition animations only.
    // It becomes .empty when transition is over.
    public let previousState: PreviousState

    public init(
      currentStateID: DivStateID,
      previousState: PreviousState
    ) {
      self.currentStateID = currentStateID
      self.previousState = previousState
    }
  }

  public enum PreviousState: Equatable {
    case empty
    // Exact state id is unknown becuase it is initial state, it was not
    // stored in DivStateManager yet.
    case initial
    case withID(DivStateID)
  }

  private let rwLock = RWLock()

  private var _items: [DivStatePath: Item]
  private var _stateBindings: [DivStatePath: Binding<String>] = [:]
  private var _blockIds: [DivStatePath: Set<String>] = [:]
  private var _blockVisibility: [DivBlockPath: Bool] = [:]

  public var items: [DivStatePath: Item] {
    rwLock.read {
      _items
    }
  }

  public var blockIds: [DivStatePath: Set<String>] {
    rwLock.read {
      _blockIds
    }
  }

  public var blockVisibility: [DivBlockPath: Bool] {
    rwLock.read {
      _blockVisibility
    }
  }

  public init() {
    self._items = [:]
  }

  public init(items: [DivStatePath: Item]) {
    self._items = items
  }

  func get(stateBlockPath: DivStatePath) -> Item? {
    rwLock.read {
      _items[stateBlockPath]
    }
  }

  func setState(stateBlockPath: DivStatePath, stateBinding: Binding<String>) {
    rwLock.write {
      _stateBindings[stateBlockPath] = stateBinding
      guard stateBinding.value != _items[stateBlockPath]?.currentStateID.rawValue else { return }
      updateState(path: stateBlockPath, stateID: DivStateID(rawValue: stateBinding.value))
    }
  }

  func resetBinding(for stateBlockPath: DivStatePath) {
    rwLock.write {
      _ = _stateBindings.removeValue(forKey: stateBlockPath)
    }
  }

  public func setState(stateBlockPath: DivStatePath, stateID: DivStateID) {
    rwLock.write {
      _stateBindings[stateBlockPath]?.value = stateID.rawValue
      _items[stateBlockPath] = Item(
        currentStateID: stateID,
        previousState: .empty
      )
    }
  }

  public func setStateWithHistory(path: DivStatePath, stateID: DivStateID) {
    rwLock.write {
      updateState(path: path, stateID: stateID)
    }
  }

  private func updateState(path: DivStatePath, stateID: DivStateID) {
    // need to take a write lock before
    let previousItem = _items[path]
    let previousState: PreviousState = if let previousStateID = previousItem?.currentStateID {
      .withID(previousStateID)
    } else {
      .initial
    }
    _stateBindings[path]?.value = stateID.rawValue
    _items[path] = Item(
      currentStateID: stateID,
      previousState: previousState
    )
  }

  public func removeState(path: DivStatePath) {
    rwLock.write {
      _ = _items.removeValue(forKey: path)
    }
  }

  public func isBlockAdded(_ id: String, stateBlockPath: DivStatePath) -> Bool {
    rwLock.read {
      guard let item = _items[stateBlockPath],
            let currentBlockIds = _blockIds[stateBlockPath + item.currentStateID] else {
        return false
      }

      switch item.previousState {
      case .empty:
        return false
      case .initial:
        if currentBlockIds.contains(id) {
          return true
        }
      case let .withID(previousStateId):
        if currentBlockIds.contains(id),
           let previousBlockIds = _blockIds[stateBlockPath + previousStateId],
           !previousBlockIds.contains(id) {
          return true
        }
      }

      return false
    }
  }

  public func updateBlockIdsWithStateChangeTransition(statePath: DivStatePath, div: Div) {
    rwLock.write {
      _blockIds[statePath] = div.idsWithStateChangeTransitionInCurrentState
    }
  }

  public func getVisibleIds(statePath: DivStatePath) -> Set<String> {
    rwLock.read {
      var ids = _blockIds[statePath] ?? Set<String>()
      _blockVisibility.forEach { blockPath, isVisible in
        if blockPath.statePath == statePath {
          if isVisible {
            ids.insert(blockPath.blockId)
          } else {
            ids.remove(blockPath.blockId)
          }
        }
      }
      return ids
    }
  }

  public func shouldBlockAppearWithTransition(path: DivBlockPath) -> Bool {
    rwLock.read {
      _blockVisibility[path] == false
    }
  }

  public func setBlockVisibility(statePath: DivStatePath, div: DivBase, isVisible: Bool) {
    if case .value = div.visibility {
      // visibility is constant
      return
    }

    rwLock.write {
      if let id = div.id, div.shouldApplyTransition(.visibilityChange) {
        _blockVisibility[statePath + id] = isVisible
      }
    }
  }

  public func reset() {
    rwLock.write {
      _items = [:]
      _blockIds = [:]
      _blockVisibility = [:]
    }
  }
}

extension DivStateManager: Equatable {
  public static func ==(lhs: DivStateManager, rhs: DivStateManager) -> Bool {
    lhs.items == rhs.items
  }
}

extension Div {
  fileprivate var idsWithStateChangeTransitionInCurrentState: Set<String> {
    var items: [String] = []
    items.appendIdWithStateChangeTransition(div: self)
    if case .divState = self {
      return Set(items)
    }
    children.forEach {
      items.append(contentsOf: $0.idsWithStateChangeTransitionInCurrentState)
    }
    return Set(items)
  }
}

extension DivBase {
  fileprivate func shouldApplyTransition(_ trigger: DivTransitionTrigger) -> Bool {
    if transitionIn == nil, transitionOut == nil, transitionChange == nil {
      return false
    }
    guard let triggers = transitionTriggers else {
      return trigger == .stateChange || trigger == .visibilityChange
    }
    return triggers.contains(trigger)
  }
}

extension [String] {
  fileprivate mutating func appendIdWithStateChangeTransition(div: Div) {
    if let id = div.id, div.value.shouldApplyTransition(.stateChange) {
      append(id)
    }
  }
}
