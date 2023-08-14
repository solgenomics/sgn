/*
creates and populates select menu with lists and datasets for analysis tools.
*/

class SelectMenu {
  constructor(menuId, menuClass, label) {
    menuId = menuId.replace(/#/, "");
    if(menuClass) {
    menuClass = menuClass.replace(/\./, "");
    }

    this.menuId = menuId;
    this.menuClass = menuClass || "form-control";
    this.label = label || ''; // || "Select a population";
    this.menu;
  }

  createSelectMenu() {
    var menu = document.createElement("select");
    menu.id = this.menuId;
    menu.className = this.menuClass;

    var option = document.createElement("option");
    option.selected = this.label;
    option.value = "";
    option.innerHTML = this.label;
    // option.disabled = true;

    menu.appendChild(option);

    this.menu = menu;
    return menu;
  }

  addOptions(data) {
    var menu = this.menu;
    if (!menu) {
      menu = this.createSelectMenu();
    }

    data.forEach(function (dt) {
      var option = document.createElement("option");

      option.value = dt.id;
      option.dataset.pop = JSON.stringify(dt);
      option.innerHTML = dt.name;

      menu.appendChild(option);

    });

    return menu;
  }

  addOptionsSeparator (text) {
    var option = document.createElement("option");
    option.innerHTML = `-------- ${text.toUpperCase()} --------`;
    option.disabled = true;

    this.menu.appendChild(option);
  }

  getSelectMenuByTypes (listTypes, datasetTypes) {
    var list = new CXGN.List();
    var lists = list.getLists(listTypes);
    var privateLists = list.convertArrayToJson(lists.private_lists);

    privateLists = privateLists.flat();
    var selectMenu = this.addOptions(privateLists);

    if (lists.public_lists[0]) {
      var publicLists = list.convertArrayToJson(lists.public_lists);
      this.addOptionsSeparator("public lists");
      selectMenu = this.addOptions(publicLists);
    }

    var datasetPops = solGS.dataset.getDatasetPops(datasetTypes);
    if (datasetPops) {
      this.addOptionsSeparator("datasets");
      selectMenu = this.addOptions(datasetPops);
    }

    return selectMenu;
   
  }

}
