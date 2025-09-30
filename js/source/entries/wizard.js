import "../legacy/CXGN/List.js";
import { Wizard } from "../modules/wizard-search.js";
import { WizardDatasets } from "../modules/wizard-datasets.js";
import { WizardDownloads } from "../modules/wizard-downloads.js";

const initialtypes = [
    "accessions",
    "accessions_ids",
    "organisms",
    "tissue_samples",
    "breeding_programs",
    "genotyping_protocols",
    "genotyping_projects",
    "locations",
    "seedlots",
    "trait_components",
    "traits",
    "trials",
    "trial_designs",
    "trial_types",
    "years"
];

const types = {
  "accessions": "Accessions",
  "accessions_ids": "Accessions Ids",
  "organisms": "Organisms",
  "breeding_programs": "Breeding Programs",
  "genotyping_protocols": "Genotyping Protocols",
  "genotyping_projects": "Genotyping Projects",
  "locations": "Locations",
  "plots": "Plots",
  "subplots": "Subplots",
  "plants": "Plants",
  "tissue_sample": "Tissue Samples",
  "seedlots": "Seedlots",
  "trait_components": "Trait Components",
  "traits": "Traits",
  "trials": "Trials",
  "trial_designs": "Trial Designs",
  "trial_types": "Trial Types",
  "years": "Years"
};

// Helper: UI/validation uses canonical plural
const toValidateType = (t) => (t === "tissue_sample" ? "tissue_samples" : t);
// Helper: data ops/URLs use legacy singular
const toLoadType = (t) => (t === "tissue_samples" ? "tissue_sample" : t);

// Allow both forms when FETCHING lists so legacy lists appear
const fetchTypes = [...new Set([...initialtypes, "tissue_sample", "subplots", "plants", "plots"])];

function makeURL(target, id) {
    switch (target) {
        case "accessions":
        case "accessions_ids":
        case "plants":
        case "plots":
        case "subplot":
        case "tissue_sample":
        case "tissue_samples": // support both; URLs expect stock path
          return document.location.origin + `/stock/${id}/view`;
        case "seedlots":
          return document.location.origin + `/breeders/seedlot/${id}`;
        case "breeding_programs":
          return document.location.origin + `/breeders/manage_programs`;
        case "locations":
          return document.location.origin + `/breeders/locations`;
        case "traits":
        case "trait_components":
          return document.location.origin + `/cvterm/${id}/view`;
        case "trials":
          return document.location.origin + `/breeders/trial/${id}`;
        case "genotyping_protocols":
          return document.location.origin + `/breeders_toolbox/protocol/${id}`;
        case "genotyping_projects":
          return document.location.origin + `/breeders/trial/${id}`;
        case "trial_designs":
        case "trial_types":
        case "years":
        default:
          return null;
    }
}

export function WizardSetup(main_id) {
  var list = new CXGN.List();

  var wiz = new Wizard(d3.select(main_id).select(".wizard-main").node(), 4)
    .types(types)
    .initial_types(initialtypes)

    // Column 1 loader
    .load_initial((target) => {
      var formData = new FormData();
      formData.append('categories[]', target); // server should receive canonical (plural) here
      formData.append('data', '');
      return fetch(window.location.origin + "/ajax/breeder/search", {
        method: "POST",
        credentials: 'include',
        body: formData
      })
      .then(resp => resp.json())
      .then(json => {
        const loadType = toLoadType(target); // use singular for URL building
        return (json.list || []).map(d => ({ id: d[0], name: d[1], url: makeURL(loadType, d[0]) }));
      });
    })

    // Subsequent columns loader
    .load_selection((target, categories, selections, operations) => {
      if (categories.some(c => (selections[c] || []).length < 1)) {
        return Promise.resolve([]); // keep return type Promise
      }
      var formData = new FormData();
      categories.forEach((c, i) => {
        formData.append('categories[]', c);
        formData.append('querytypes[]', operations[c]);
        (selections[c] || []).forEach(s => {
          formData.append(`data[${i}][]`, s.id);
        });
      });
      formData.append('categories[]', target);
      return fetch(window.location.origin + "/ajax/breeder/search", {
        method: "POST",
        credentials: 'include',
        body: formData
      })
      .then(resp => resp.json())
      .then(json => {
        if (!Array.isArray(json.list)) return [];
        const loadType = toLoadType(target); // use singular for URL building
        return json.list.map(d => ({ id: d[0], name: d[1], url: makeURL(loadType, d[0]) }));
      });
    })

    // Load a list’s contents
    .load_list((listID) => {
      return new Promise(res => {
        const ids   = list.transform2Ids(listID);
        const ldata = list.getListData(listID);

        const rawType      = (ldata?.type_name ?? "").trim();
        const validateType = toValidateType(rawType);
        const loadType     = toLoadType(validateType);

        if (!fetchTypes.includes(validateType)) {
          setTimeout(() => alert("List is not of an appropriate type."), 1);
        }


        // Build items; if transform2Ids fails, fall back to elements
        const elements = Array.isArray(ldata?.elements) ? ldata.elements : [];
        const useIds   = !ids?.error && Array.isArray(ids) && ids.length === elements.length;

        const items = elements.map((el, i) => {
          let name, fallbackId = null;
          if (Array.isArray(el)) {
            name = (el[1] ?? el[0] ?? "").toString();
            fallbackId = el[0] ?? null;
          } else if (el && typeof el === "object") {
            name = (el.name ?? el.label ?? "").toString();
            fallbackId = el.id ?? null;
          } else {
            name = String(el ?? "");
          }
          const ele_id = useIds ? ids[i] : fallbackId;
          const url    = ele_id ? makeURL(loadType, ele_id) : null;
          return { id: ele_id, name, url };
        });

        res({ type: validateType, items });
      });
    });

  // Populate dropdowns (allow both forms to appear, show plural in UI)
  var load_lists = () => (new Promise((resolve) => {
    let private_lists = list.availableLists(fetchTypes);
    let public_lists  = list.publicLists(fetchTypes);
    if (public_lists.error) public_lists = [];
    if (private_lists.error) private_lists = [];
    resolve(private_lists.concat(public_lists));
  }))
  .then(lists => lists.reduce((acc, cur) => {
    const uiType = toValidateType(cur[5]); // cur = [id, name, ..., type]
    acc[cur[0]] = { name: cur[1], type: uiType };
    return acc;
  }, {}))
  .then(listdict => {
    wiz.lists(listdict);
  });

  load_lists();

  wiz.add_to_list((listID, items) => {
    var count = list.addBulk(listID, items.map(i => i.name));
    if (count) alert(`${count} items added to list.`);
    load_lists();
  })
  .create_list((listName, colType, items) => {
    var newID = list.newList(listName, "");
    if (newID) {
      list.setListType(newID, colType);
      var count = list.addBulk(newID, items.map(i => i.name));
      if (count) alert(`${count} items added to list ${listName}.`);
    }
    load_lists();
  });

  var down = new WizardDownloads(d3.select(main_id).select(".wizard-downloads").node(), wiz);
  var dat  = new WizardDatasets(d3.select(main_id).select(".wizard-datasets").node(), wiz);

  var lo = new CXGN.List();
  jQuery('#wizard-download-genotypes-marker-set-list-id')
    .html(lo.listSelect('wizard-download-genotypes-marker-set-list-id', ['markers'], 'Select a list', 'refresh', undefined));

  return {
    wizard: wiz,
    reload_lists: load_lists
  };
}

export function updateStatus(element) {
  return fetch(
    document.location.origin + '/ajax/breeder/check_status',
    {
      method: 'POST',
      credentials: 'include'
    }
  ).then(resp => resp.json())
  .then(json => {
    var innerhtml = "";
    if (json.refreshing) innerhtml = json.refreshing;
    else if (json.timestamp) innerhtml = json.timestamp;
    else throw new Error(json.error);
    d3.select(element).html(innerhtml);
    return !!json.refreshing;
  })
  .catch(err => {
    d3.select(element).html(`<font color="red">${err.message} - If this problem persists, please <a href="../../contact/form">contact developers</a></font>`);
    return false;
  });
}

// "fullview" for refreshing materialized phenoview, genoview, traits, and stockprop
// "stockprop" for refreshing materialized stockprop
export function refreshMatviews(matview_select, button) {
  d3.select(button).attr("disabled", true);
  fetch(
    document.location.origin + `/ajax/breeder/refresh?matviews=${matview_select}`,
    {
      method: 'POST',
      credentials: 'include'
    }
  ).then(resp => resp.json())
  .then(json => {
    if (json.error) {
      throw new Error(json.error);
    } else {
      d3.select("#update_wizard_error")
        .style("display", null)
        .html('<font color="green">' + json.message + '</font></div>');
    }
  })
  .catch(err => {
    d3.select("#update_wizard_error")
      .style("display", null)
      .html('<font color="red">' + err.message + '</font>');
  });
}
