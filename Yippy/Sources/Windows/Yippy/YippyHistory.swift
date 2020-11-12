//
//  YippyHistory.swift
//  Yippy
//
//  Created by Matthew Davidson on 4/10/19.
//  Copyright © 2019 MatthewDavidson. All rights reserved.
//

import Foundation
import Cocoa

class YippyHistory {
    
    let history: History
    var items: [HistoryItem]
    
    let pasteboard: NSPasteboard
    
    init(history: History, items: [HistoryItem]) {
        self.history = history
        self.items = items
        self.pasteboard = NSPasteboard.general
    }
    
    func paste(selected: Int) {
        // Internally action the pasteboard change
        // Our pasteboard monitor will detect the change
        // But our `History` will know that it has already been consumed
        history.moveItem(at: selected, to: 0)
        let newChangeCount = pasteboard.clearContents()
        history.recordPasteboardChange(withCount: newChangeCount)
        
        // Write object
        pasteboard.writeObjects([items[selected]])
        
        Helper.pressCommandV()
    }
    
    func delete(selected: Int) {
        history.deleteItem(at: selected)
        if selected == 0 {
            // If we want to remove this, then we may have to change the `HistoryItem` writingOptions() to not `.promised`, because if something is pasted from history, then deleted, it can no longer satisfy the promise.
            pasteboard.clearContents()
        }
        
        // Assume no selection
        var select: Int? = nil
        // If the deleted item is not the last in the list then keep the selection index the same.
        if selected < items.count - 1 {
            select = selected
        }
        // Otherwise if there is any items left, select the previous item
        else if selected > 0 {
            select = selected - 1
        }
        // No items, select nothing
        else {
            select = nil
        }
        history.setSelected(select)
    }
    
    func move(from: Int, to: Int) {
        history.moveItem(at: from, to: to)
        
        if to == 0 {
            let newChangeCount = pasteboard.clearContents()
            history.recordPasteboardChange(withCount: newChangeCount)
            
            // Write object
            pasteboard.writeObjects([items[from]])
        }
        
        history.setSelected(to)
    }

    func filtering(_ filter: String) -> [HistoryItem] {
        if filter.count > 0 {
            let isImageSearch = filter.contains("image")
            return items.filter {
                $0.getPlainString()?.contains(filter) == true || $0.getImage() != nil && isImageSearch
            }
        } else {
            return self.items;
        }
    }
}

