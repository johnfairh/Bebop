// J2 FW2020 theme.
//
// Distributed under the MIT license, https://github.com/johnfairh/J2/blob/master/LICENSE
//
$(function() {
    $("#navToggleButton").click(function() {
        const $nav = $("#navColumn")
        $nav.toggleClass("d-none")
    });
});

Prism.languages.swift['builtin'] = /\b(?:[A-Z]\S*)\b/;

Prism.plugins.autoloader['languages_path'] = "https://cdnjs.cloudflare.com/ajax/libs/prism/1.17.1/components/";
