/** @file Locale captions and canonical navigation for the standard Bookdown reader. */
(function () {
    "use strict";
    function init() {
        var node = document.getElementById("manual-locale-ui");
        if (!node) return;
        var ui = JSON.parse(node.textContent);
        function translate(value) { return Object.prototype.hasOwnProperty.call(ui.labels, value) ? ui.labels[value] : value; }
        function apply() {
            document.querySelectorAll(".book-header [title],.book-header [aria-label],#search-box,.anchor-section-link,[aria-label='Anchor link to header']").forEach(function (element) {
                ["title", "aria-label", "placeholder"].forEach(function (name) {
                    var value = element.getAttribute(name);
                    if (value !== null) element.setAttribute(name, translate(value));
                });
            });
            document.querySelectorAll(".book-header .dropdown-menu .button,label[for='search-box']").forEach(function (element) {
                var value = element.textContent.trim(), localized = translate(value);
                if (localized !== value) element.textContent = localized;
            });
            var missing = document.getElementById("section-");
            if (missing) {
                missing.querySelectorAll("h1,p").forEach(function (element) {
                    var value = element.textContent.trim(), localized = translate(value);
                    if (localized !== value) element.textContent = localized;
                });
                document.title = document.title.replace("Page not found", translate("Page not found"));
            }
            var parent = document.querySelector(".page-inner");
            if (parent && !parent.querySelector(".manual-language-nav")) {
                var nav = document.createElement("nav");
                nav.className = "manual-language-nav";
                nav.setAttribute("aria-label", ui.language);
                var label = document.createElement("span"); label.textContent = ui.language + ":"; nav.appendChild(label);
                var file = location.pathname.split("/").pop() || "index.html";
                [["en","English"],["uk","Українська"],["es","Español"],["ar","العربية"]].forEach(function (item) {
                    var link = document.createElement("a");
                    link.textContent = item[1]; link.lang = item[0];
                    link.href = (item[0] === "en" ? "../" : "../" + item[0] + "/") + file + location.hash;
                    if (item[0] === ui.locale) link.setAttribute("aria-current", "page");
                    nav.appendChild(link);
                });
                parent.insertBefore(nav, parent.firstChild);
            }
        }
        apply();
        if (window.gitbook && gitbook.events) {
            gitbook.events.bind("start", function () { window.setTimeout(apply, 0); });
            gitbook.events.bind("page.change", function () { window.setTimeout(apply, 0); });
        }
        var observer = new MutationObserver(apply);
        document.querySelectorAll(".book-header,.book-summary").forEach(function (element) {
            observer.observe(element, {childList: true, subtree: true});
        });
        window.setTimeout(apply, 0);
    }
    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init); else init();
}());
