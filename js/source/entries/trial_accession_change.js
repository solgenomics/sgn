import "../legacy/jquery.js";

/**
 * Changes of what grows on the plots of a field trial: the Change Accessions
 * upload (a file of what was planted, which can also mark plots as not
 * planted or as rejected) and Replace Accession (Field Layout Tools -> Edit
 * Field Layout).
 *
 * The endpoints answer with a summary (see CXGN::Trial::AccessionChange::summary()):
 * with preview=1 what would change ({ preview: summary }), otherwise what changed
 * ({ success: 1, ...summary }). Otherwise they answer { error }, or { warning }
 * when a curator has to confirm a change of a trial that has phenotypes or seedlots.
 * Errors about phenotypes of plots marked as not planted come with
 * not_planted_phenotypes, the number of those values.
 */

/**
 * The lines that describe a summary, without HTML.
 * @param {Object} summary - the summary (or the preview) from the server
 * @param {boolean} planned - true for a preview (what will change), false for what changed
 * @param {number} [maxItems=10] - how many plots to list for renames, check marks and planting
 * @returns {string[]}
 */
export function summaryLines(summary, planned, maxItems = 10) {
    const lines = [];
    const list = (items, describe) => {
        items.slice(0, maxItems).forEach((item) => lines.push("    " + describe(item)));
        if (items.length > maxItems) {
            lines.push("    ... and " + (items.length - maxItems) + " more");
        }
    };

    if (planned && summary.rows_read !== undefined) {
        lines.push(`${summary.rows_read} plot(s) read from the file.`);
    }
    const planting = summary.planting || [];
    const rejections = summary.rejections || [];
    if (summary.changed || (!planting.length && !rejections.length)) {
        const changes = summary.changes || [];
        lines.push(`${summary.changed} plot(s) ${planned ? "will get" : "got"} another accession${changes.length ? ":" : "."}`);
        list(changes, (c) => `${c.plot_name}: ${c.old_stock_name} -> ${c.new_stock_name}`);
    }
    const notPlanted = planting.filter((p) => p.not_planted);
    const planted = planting.filter((p) => !p.not_planted);
    if (notPlanted.length) {
        lines.push(`${notPlanted.length} plot(s) ${planned ? "will be" : "were"} marked as not planted:`);
        list(notPlanted, (p) => p.plot_name);
    }
    if (planted.length) {
        lines.push(`${planted.length} plot(s) ${planned ? "will be" : "were"} marked as planted again:`);
        list(planted, (p) => p.plot_name);
    }
    const rejected = rejections.filter((r) => r.rejected && !r.was_rejected);
    const newReason = rejections.filter((r) => r.rejected && r.was_rejected);
    const unrejected = rejections.filter((r) => !r.rejected);
    if (rejected.length) {
        lines.push(`${rejected.length} plot(s) ${planned ? "will be" : "were"} rejected (the data stay, but are left out of downloads and analyses):`);
        list(rejected, (r) => r.plot_name + (r.reject_reason ? ` (${r.reject_reason})` : ""));
    }
    if (newReason.length) {
        lines.push(`${newReason.length} rejected plot(s) ${planned ? "will get" : "got"} another reject reason:`);
        list(newReason, (r) => `${r.plot_name}: ${r.reject_reason || "(none)"}`);
    }
    if (unrejected.length) {
        lines.push(`${unrejected.length} plot(s) ${planned ? "will be" : "are"} no longer rejected:`);
        list(unrejected, (r) => r.plot_name);
    }
    if (summary.replicates_changed) {
        lines.push(`${summary.replicates_changed} accession occurrence number(s) ${planned ? "will be" : "were"} numbered again by plot number; recorded design groups stay unchanged.`);
    }
    if (summary.checks && summary.checks.length) {
        lines.push(`Check plots ${planned ? "that will change" : "that changed"}:`);
        list(summary.checks, (k) => k.plot_name + (k.check ? " becomes a check plot" : " becomes a test plot"));
    }
    if (summary.renamed && summary.renamed.length) {
        lines.push(`${summary.renamed.length} plot(s) ${planned ? "will be renamed" : "were renamed"}:`);
        list(summary.renamed, (r) => `${r.old_name} -> ${r.new_name}`);
    }
    (summary.not_renamed || []).forEach((r) => lines.push(`Not renamed: ${r.plot_name} (${r.reason})`));
    const seedlots = summary.seedlots || [];
    const moves = seedlots.filter((t) => t.type === "move");
    if (moves.length) {
        lines.push(`${moves.length} seed transaction(s) ${planned ? "will follow" : "followed"} their packets:`);
        list(moves, (t) => `${t.seedlot_name}: ${t.from_plot_name} -> ${t.plot_name}`);
    }
    const otherSeedlot = seedlots.filter((t) => t.type === "seedlot");
    if (otherSeedlot.length) {
        lines.push(`${otherSeedlot.length} plot(s) ${planned ? "will get" : "got"} another seedlot:`);
        list(otherSeedlot, (t) => `${t.plot_name}: ${t.old_seedlot_name} -> ${t.seedlot_name}`);
    }
    const restored = seedlots.filter((t) => t.type === "restore");
    if (restored.length) {
        lines.push(`${restored.length} plot(s) ${planned ? "will get" : "got"} back the packet an earlier correction left in no plot:`);
        list(restored, (t) => `${t.plot_name}: ${t.seedlot_name}`);
    }
    const taken = seedlots.filter((t) => t.type === "taken");
    if (taken.length) {
        lines.push(`${taken.length} packet(s) ${planned ? "will be" : "are"} in no plot (for example planted into a border); their seed stays taken from the seedlot:`);
        list(taken, (t) => `${t.seedlot_name} (was linked to ${t.plot_name})`);
    }
    (summary.entry_numbers || []).forEach((e) => lines.push(`${e.stock_name}${planned ? " will get" : " got"} entry number ${e.entry_number}.`));
    if (!planned && summary.phenotypes_deleted) {
        lines.push(`${summary.phenotypes_deleted} phenotype value(s) were deleted.`);
    }
    (summary.warnings || []).forEach((w) => lines.push("Note: " + w));
    return lines;
}

/**
 * The plots that a change touched, by their names after it (for new labels and files).
 * @param {Object} summary - what changed (the summary from the server)
 * @returns {string[]}
 */
export function changedPlots(summary) {
    const newName = new Map((summary.renamed || []).map((r) => [r.old_name, r.new_name]));
    const names = [
        ...(summary.changes || []).map((c) => c.plot_name),
        ...(summary.renamed || []).map((r) => r.old_name),
        ...(summary.planting || []).map((p) => p.plot_name),
        ...(summary.rejections || []).map((r) => r.plot_name),
        ...(summary.checks || []).map((c) => c.plot_name),
        ...(summary.seedlots || []).flatMap((s) => [s.from_plot_name, s.plot_name]),
    ];
    // affected_plots is already expressed in final names by the server. Do not
    // rename it again: one plot's final name may be another plot's old name.
    return [...new Set([
        ...(summary.affected_plots || []),
        ...names.filter((name) => name).map((name) => newName.get(name) || name),
    ])];
}

/**
 * Whether a plan changes nothing, for example a file that the trial already matches.
 * @param {Object} summary - the preview from the server
 * @returns {boolean}
 */
export function trialHasPhenotypes(trialId) {
    // whether data was collected with the plot names: then they are kept by default
    return new Promise((resolve) => {
        jQuery.ajax({
            // phenotypes of plots, plants, subplots and samples, and NIRS and other high-dimensional
            // data; treatments do not count (the same values as the warnings of a change)
            url: `/ajax/breeders/trial/${trialId}/accession_change_defaults`,
            success: (response) => resolve(!!(response && response.has_phenotypes == 1)),
            error: () => resolve(true),   // when in doubt, keep the names
        });
    });
}

/**
 * Whether the plots are renamed by default: while a trial is planned (no phenotypes yet) the
 * names follow the accessions (template, then the accession name in the plot name); once data
 * was collected with the plot names, they are kept unless the user asks.
 * @param {boolean} hasPhenotypes
 * @returns {boolean}
 */
export function renameByDefault(hasPhenotypes) {
    return !hasPhenotypes;
}

/**
 * @param {object} summary
 * @returns {boolean} whether the summary changes nothing
 */
export function nothingChanges(summary) {
    return !summary.changed && !summary.replicates_changed && !summary.phenotypes_deleted
        && !(summary.planting || []).length && !(summary.rejections || []).length && !(summary.renamed || []).length
        && !(summary.checks || []).length && !(summary.entry_numbers || []).length
        && !(summary.seedlots || []).length;
}

/**
 * Shows the lines of a summary as the items of a list.
 * @param {string|HTMLElement} list - the ul element, or its selector
 * @param {Object} summary - the summary from the server
 * @param {boolean} planned - true for a preview, false for what changed
 */
export function showSummary(list, summary, planned) {
    const ul = jQuery(list).empty();
    summaryLines(summary, planned, 50).forEach((line) => ul.append(jQuery("<li/>").css("white-space", "pre-wrap").text(line)));
}

function hasModals() {
    return typeof jQuery.fn.modal === "function";
}

// shows or hides the "Working..." dialog of the page, when there is one;
// resolves once it is hidden, so that another dialog can open
function working(show) {
    const modal = jQuery("#working_modal");
    if (!modal.length || !hasModals()) {
        return Promise.resolve();
    }
    if (show) {
        modal.modal("show");
        return Promise.resolve();
    }
    return new Promise((resolve) => {
        const state = modal.data("bs.modal");
        if (!state || !state.isShown) {
            resolve();
            return;
        }
        modal.one("hidden.bs.modal", () => resolve());
        setTimeout(resolve, 1000);
        modal.modal("hide");
    });
}

// the data with more parameters; a FormData (a form with a file) is copied
function withParams(data, params) {
    if (typeof FormData !== "undefined" && data instanceof FormData) {
        const form = new FormData();
        data.forEach((value, key) => form.append(key, value));
        Object.entries(params).forEach(([key, value]) => form.set(key, value));
        return form;
    }
    return { ...data, ...params };
}

/**
 * The text of an error that the server sent as HTML (lines separated by <br>),
 * without running anything in it.
 * @param {string} html
 * @returns {string}
 */
export function plainText(html) {
    return new DOMParser().parseFromString(String(html).replace(/<br\s*\/?>/gi, "\n"), "text/html").body.textContent;
}

function post(url, data) {
    const request = { type: "POST", url, data, dataType: "json", traditional: true };
    if (typeof FormData !== "undefined" && data instanceof FormData) {
        // sent as multipart/form-data, as the form would send it
        request.processData = false;
        request.contentType = false;
    }
    working(true);
    return new Promise((resolve) => {
        jQuery.ajax(request)
            .done((response) => working(false).then(() => resolve(response || {})))
            .fail(() => working(false).then(() => resolve({ error: "The server could not be reached, or it failed; nothing may have been changed." })));
    });
}

/**
 * Asks the user in a dialog of the page that shows each line of the message,
 * on top of any dialog that is open. Falls back to window.confirm.
 * @param {string} message - lines separated by newlines
 * @param {Object} [options]
 * @param {string} [options.title="Please check"] - the title of the dialog
 * @param {string} [options.ok="Continue"] - the button that says yes
 * @param {string|null} [options.cancel="Cancel"] - the button that says no; null for a message with one button
 * @returns {Promise<boolean>} true when the user clicked the ok button
 */
export function confirmDialog(message, { title = "Please check", ok = "Continue", cancel = "Cancel" } = {}) {
    if (!hasModals()) {
        return Promise.resolve(window.confirm(message));
    }
    return new Promise((resolve) => {
        const dialog = jQuery(`<div class="modal fade" tabindex="-1" role="dialog" style="z-index: 1070">
            <div class="modal-dialog" role="document"><div class="modal-content">
                <div class="modal-header"><h4 class="modal-title"></h4></div>
                <div class="modal-body"><ul class="list-unstyled" style="white-space: pre-wrap; margin: 0"></ul></div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-default" data-answer="no">Cancel</button>
                    <button type="button" class="btn btn-primary" data-answer="yes"></button>
                </div>
            </div></div></div>`);
        dialog.attr("aria-label", title);
        dialog.find(".modal-title").text(title);
        dialog.find(".btn-primary").text(ok);
        if (cancel) {
            dialog.find("[data-answer=no]").text(cancel);
        } else {
            dialog.find("[data-answer=no]").remove();
        }
        message.split("\n").filter((line) => line.trim() !== "").forEach((line) => {
            dialog.find("ul").append(jQuery("<li/>").text(line));
        });
        let answer = false;
        dialog.on("click", "[data-answer]", function () {
            answer = jQuery(this).data("answer") === "yes";
            dialog.modal("hide");
        });
        dialog.on("hidden.bs.modal", () => {
            dialog.remove();
            // Bootstrap forgets that a dialog below this one is still open
            if (jQuery(".modal.in").length) {
                jQuery("body").addClass("modal-open");
            }
            resolve(answer);
        });
        jQuery("body").append(dialog);
        dialog.modal({ backdrop: "static", show: true });
        jQuery(".modal-backdrop").last().css("z-index", 1065);
    });
}

/**
 * Makes a change after the user has seen it: posts the request with preview=1,
 * shows what will change and asks to continue, then posts it again to change,
 * with the plan_digest of the preview, so that the server changes nothing else.
 * A curator confirms a change of a trial with data (the request is repeated
 * with override=1). A not-planted change that conflicts with existing values
 * is refused; this correction flow never asks to delete observations.
 * Errors are shown with alert.
 * @param {string} url - e.g. /ajax/breeders/trial/<id>/replace_stock
 * @param {Object|FormData} data - the parameters of the change; a FormData for a form with a file
 * @param {Object} [options]
 * @param {string} [options.action="Change"] - names the change in error messages
 * @param {string} [options.title="Please check the changes"] - the title of the question with the plan
 * @param {function(string, Object): (boolean|Promise<boolean>)} [options.confirm] - asks the user, with { title, ok }; confirmDialog by default
 * @param {function(string, string): void} [options.alert] - tells the user about an error, with the error from the server alone as the second argument; window.alert by default
 * @param {function(string): (void|Promise)} [options.inform] - tells the user something that is not an error; options.alert by default
 * @returns {Promise<Object|null>} what changed (the summary), or null when nothing was changed
 */
export async function changeWithPreview(url, data, options = {}) {
    const action = options.action || "Change";
    const ask = options.confirm || confirmDialog;
    const tell = options.alert || ((message) => window.alert(message));
    const inform = options.inform || tell;
    const params = {};

    for (;;) {
        const response = await post(url, withParams(data, { ...params, preview: 1 }));
        if (response.warning) {
            if (params.override || !(await ask(`${plainText(response.warning)}\n\nChange it anyway?`, { title: "Only a curator can change this trial", ok: "Change it anyway" }))) {
                return null;
            }
            params.override = 1;
            continue;
        }
        if (response.error) {
            tell(`${action}: ${response.error}`, response.error);
            return null;
        }
        if (response.preview && nothingChanges(response.preview)) {
            const notes = (response.preview.warnings || []).map((w) => "\nNote: " + w).join("");
            await inform("Nothing to change: the trial already matches." + notes);
            return null;
        }
        // every change is listed, so that nothing (for example a change undone by an old file) goes unseen
        if (!response.preview || !(await ask(summaryLines(response.preview, true, Infinity).join("\n") + "\n\nContinue?", { title: options.title || "Please check the changes", ok: "Continue" }))) {
            return null;
        }
        // the server refuses to change anything but what the user saw
        if (response.preview.plan_digest) {
            params.plan_digest = response.preview.plan_digest;
        }
        break;
    }

    const response = await post(url, withParams(data, params));
    if (!response.success) {
        const error = response.error || response.warning || "The trial was not changed.";
        tell(`${action}: ${error}`, error);
        return null;
    }
    return response;
}
