//
//  MergeImport.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

//
// Stuff to do with building the initial DefItem forest from GatherPasses
// See also `DefItem.init(...)`.
//

struct MergeImport {
    init(config: Config) {
    }

    /// Flatten and interpret the gather info into `DefItem` trees.
    func importItems(gathered: [GatherModulePass]) -> [DefItem] {
        let uniquer = StringUniquer()

        return gathered.map { pass in
            pass.files.map { fileDef -> [DefItem] in
                let filePathname = fileDef.0
                let rootDef = fileDef.1
                guard rootDef.sourceKittenDict.diagnosticStage != nil else {
                    logWarning(.localized(.wrnMergeMissingRoot, filePathname, pass.passIndex))
                    return []
                }
                let baseLocation = DefLocation(moduleName: pass.moduleName,
                                               passIndex: pass.passIndex,
                                               filePathname: filePathname,
                                               firstLine: nil,
                                               lastLine: nil)

                return rootDef.children.asDefItems(location: baseLocation,
                                                   uniquer: uniquer)
            }.flatMap { $0 }
        }.flatMap { $0 }
    }
}

extension Array where Element == GatherDef {
    public func asDefItems(location: DefLocation, uniquer: StringUniquer) -> [DefItem] {
        var currentTopic: Topic? = nil
        return flatMap { def -> [DefItem] in
            // Spot topic marks and pull them out for subsequent items
            if let topic = def.asTopicMark {
                currentTopic = topic
                return []
            }
            // Spot enum case wrappers and yield the element[s] within
            if let kind = def.kind, kind.isSwiftEnumCase {
                let items = def.children.asDefItems(location: location,
                                                    uniquer: uniquer)
                items.forEach { $0.topic = currentTopic }
                return items
            }
            // Finally create 0/1 items.
            guard let item = DefItem(location: location,
                                     gatherDef: def,
                                     uniquer: uniquer) else {
                return []
            }
            item.topic = currentTopic
            return [item]
        }
    }
}

extension GatherDef {
    /// Try to interpret the def as a Topic
    var asTopicMark: Topic? {
        guard let kind = kind,
            kind.isMark,
            let text = sourceKittenDict.name else {
            return nil
        }
        if kind.isSwift && !text.hasPrefix("MARK: ") {
            // TODO or FIXME - we'll throw these away later on
            return nil
        }
        // Format: 'MARK: - NAME -' with dashes and prefix optional
        guard let match = text.re_match("^(?:MARK: )?(?:- )?(.*?)(?: -)?$") else {
            return nil
        }
        return Topic(title: match[1])
    }
}
