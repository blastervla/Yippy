//
//  History.swift
//  Yippy
//
//  Created by Matthew Davidson on 16/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa
import RxSwift
import RxRelay

/// Representation of all the history
class History {
    
    private var items = [HistoryItem]()
    
    /// Behaviour relay for the last change count of the pasteboard.
    /// Private so that it cannot be manipulated outside of the class.
    private var _lastRecordedChangeCount = BehaviorRelay<Int>(value: -1)
    
    /// Observable for the last recorded change count of the pasteboard.
    var observableLastRecordedChangeCount: Observable<Int> {
        return _lastRecordedChangeCount.asObservable()
    }
    
    /// The last change count for which the items on the pasteboard have been added to the history.
    var lastRecordedChangeCount: Int {
        return _lastRecordedChangeCount.value
    }
    
    /// The file manager for the storage of pasteboard history.
    var historyFM: HistoryFileManager
    
    /// The cache for the history item.
    var cache: HistoryCache
    
    ///
    private var _selected: BehaviorRelay<Int?>
    
    private var _maxItems: BehaviorRelay<Int>
    
    var selected: Observable<Int?> {
        _selected.asObservable()
    }
    
    var maxItems: Observable<Int> {
        _maxItems.asObservable()
    }
    
    typealias InsertHandler = ([HistoryItem], Int) -> Void
    typealias DeleteHandler = ([HistoryItem], HistoryItem) -> Void
    typealias ClearHandler = () -> Void
    typealias MoveHandler = ([HistoryItem], Int, Int) -> Void
    typealias SubscribeHandler = ([HistoryItem]) -> Void
    
    private var insertObservers = [InsertHandler]()
    private var deleteObservers = [DeleteHandler]()
    private var clearObservers = [ClearHandler]()
    private var moveObservers = [MoveHandler]()
    private var subscribers = [SubscribeHandler]()
    
    init(historyFM: HistoryFileManager = .default, cache: HistoryCache, items: [HistoryItem], maxItems: Int = Constants.system.maxHistoryItems) {
        self.historyFM = historyFM
        self.cache = cache
        self.items = items
        self._selected = BehaviorRelay<Int?>(value: nil)
        self._maxItems = BehaviorRelay<Int>(value: maxItems)
        
        if items.count > maxItems {
            reduceHistory(to: maxItems)
        }
    }
    
    static func load(historyFM: HistoryFileManager = .default, cache: HistoryCache) -> History {
        return historyFM.loadHistory(cache: cache)
    }
    
    func onInsert(handler: @escaping InsertHandler) {
        insertObservers.append(handler)
    }
    
    func onDelete(handler: @escaping DeleteHandler) {
        deleteObservers.append(handler)
    }
    
    func onClear(handler: @escaping ClearHandler) {
        clearObservers.append(handler)
    }
    
    func onMove(handler: @escaping MoveHandler) {
        moveObservers.append(handler)
    }
    
    func subscribe(onNext: @escaping SubscribeHandler) {
        subscribers.append(onNext)
        onNext(items)
    }
    
    func insertItem(_ item: HistoryItem, at i: Int) {
        items.insert(item, at: i)
        insertObservers.forEach({$0(items, i)})
        subscribers.forEach({$0(items)})
        historyFM.insertItem(newHistory: items, at: i)
        
        if items.count > _maxItems.value {
            deleteItem(at: items.count - 1)
        }
    }
    
    func deleteItem(at i: Int) {
        let removed = items.remove(at: i)
        deleteObservers.forEach({$0(items, removed)})
        subscribers.forEach({$0(items)})
        historyFM.deleteItem(newHistory: items, deleted: removed)
    }
    
    func clear() {
        items.forEach({$0.stopCaching()})
        items = []
        clearObservers.forEach({$0()})
        subscribers.forEach({$0(items)})
        historyFM.clearHistory()
    }
    
    func moveItem(at i: Int, to j: Int) {
        let item = items.remove(at: i)
        items.insert(item, at: j)
        moveObservers.forEach({$0(items, i, j)})
        subscribers.forEach({$0(items)})
        historyFM.moveItem(newHistory: items, from: i, to: j)
    }
    
    func recordPasteboardChange(withCount changeCount: Int) {
        _lastRecordedChangeCount.accept(changeCount)
    }
    
    func setSelected(_ selected: Int?) {
        _selected.accept(selected)
    }
    
    func setMaxItems(_ maxItems: Int) {
        if maxItems < _maxItems.value {
            reduceHistory(to: maxItems)
        }
        _maxItems.accept(maxItems)
    }
    
    private func reduceHistory(to maxItems: Int) {
        historyFM.reduce(oldHistory: items, toSize: maxItems)
        items = Array(items.prefix(maxItems))
        subscribers.forEach({$0(items)})
    }
}

extension History: PasteboardMonitorDelegate {
    
    func pasteboardDidChange(_ pasteboard: NSPasteboard) {
        // Check if we made this pasteboard change, if so, ignore
        if pasteboard.changeCount == lastRecordedChangeCount {
            return
        }
        
        // Check there are items on the pasteboard
        guard let items = pasteboard.pasteboardItems else {
            return
        }
        
        for item in items {
            // Only do anything if the pasteboard change includes having data
            if !item.types.isEmpty {
                var data = [NSPasteboard.PasteboardType: Data]()
                for type in item.types {
                    if let d = item.data(forType: type) {
                        data[type] = d
                    }
                    else {
                        print("Warning: new pasteboard data nil for type '\(type.rawValue)'")
                    }
                }
                let historyItem = HistoryItem(unsavedData: data, cache: cache)
                guard historyItem.allData() != self.items.first?.allData() else { continue }
                insertItem(historyItem, at: 0)
                let selected = (_selected.value ?? -1) + 1
                setSelected(selected)
            }
        }
        
        // Save pasteboard change count
        recordPasteboardChange(withCount: pasteboard.changeCount)
    }
}
