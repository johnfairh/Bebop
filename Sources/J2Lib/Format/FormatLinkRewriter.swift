//
//  FormatLinkRewriter.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import Maaku

final class FormatLinkRewriter: Configurable {
    private let rewriteLinkURLs = StringListOpt(l: "rewrite-link-urls").help("SERVERURL1,SERVERURL2,...")

    private let published: Published

    init(config: Config) {
        self.published = config.published
        config.register(self)
    }

    private func shouldRewrite(href: String) -> Bool {
        for url in rewriteLinkURLs.value {
            if href.hasPrefix(url) {
                return true
            }
        }
        return false
    }

    /// Try to rewrite a link or image node to point to a guide or media file that will end up in the docset.
    /// At this point we are rewriting the markdown tree.
    func rewriteLink(node: CMNode) {
        // Look for relative URLs or absolute URLs matching user setting
        guard let originalHref = node.linkDestination,
            !originalHref.re_isMatch("^(https?://|#)") || shouldRewrite(href: originalHref),
            let basename = URL(string: originalHref)?.lastPathComponent else {
            return
        }

        if let mediaURL = published.urlPathForMedia(basename) {
            logDebug("Format: Rewrote link to media '\(mediaURL)'")
            Stats.inc(.formatRewrittenMediaLinks)
            try! node.setLinkDestination(FormatAutolink.AUTOLINK_TOKEN + mediaURL)
        } else if node.type == .link, let guideURL = published.urlPathForGuide(basename) {
            logDebug("Format: Rewrote link to guide '\(guideURL)'")
            Stats.inc(.formatRewrittenGuideLinks)
            try! node.setLinkDestination(FormatAutolink.AUTOLINK_TOKEN + guideURL)
        } else {
            // Not brave enough to make this a warning: could be legit either way
            logDebug("Format: Couldn't resolve suspicious link \(originalHref), leaving it alone.")
            Stats.inc(.formatUnrewrittenLinks)
        }
    }

    /// Update our links to guides for HTML.  This means flipping their file extension from ".md" as returned by
    /// `urlPathForGuide()` to ".html".  Hack hack.
    func rewriteLinkForHTML(node: CMNode) {
        guard let href = node.linkDestination,
            href.hasPrefix(FormatAutolink.AUTOLINK_TOKEN),
            href.hasSuffix(".md") else {
                return
        }

        let htmlHref = href.re_sub(".md$", with: ".html")
        try! node.setLinkDestination(htmlHref)
    }
}
