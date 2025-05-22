/*
creates and populates select menu with lists and datasets for analysis tools.
*/

class SelectMenu {
  constructor(menuDivId, selectId, menuClass, label) {
    menuDivId = menuDivId.replace(/#/, "");
    selectId = selectId.replace(/#/, "");
    if(menuClass) {
      menuClass = menuClass.replace(/\./, "");
    }

    this.menuDivId = menuDivId;
    this.selectId = selectId;
    this.menuClass = menuClass || "form-control";
    this.label = label || ''; // || "Select a population";
    this.menu;
  }

  createSelectMenu() {
    var menu = document.createElement("select");
    menu.id = this.selectId;
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

  getSelectMenuOptions() {
    var selectMenu = document.getElementById(this.selectId);
    var options;

    if (selectMenu) {
      options = selectMenu.options;
    }
    
    return options;
  }

  createOptionElement(dt) {
    var option = document.createElement("option");

    option.value = dt.id;
    option.dataset.pop = JSON.stringify(dt);
    option.innerHTML = dt.name;

    return option;

  }

  createOptions(data) {
    var menu = this.menu;
    if (!menu) {
      menu = this.createSelectMenu();
    }

    data.forEach(function (dt) {
      var option = this.createOptionElement(dt);
      menu.appendChild(option);
    }.bind(this));

    return menu;
  }

  updateOptions(newPop) {
    var options = this.getSelectMenuOptions();
    if (options) {
      if (newPop){
        var newOption = this.createOptionElement(newPop);
        options.add(newOption);
      }
    }

  }

  displayMenu(menuElems) {
    document.querySelector(`#${this.menuDivId}`).appendChild(menuElems);
  }

  addOptionsSeparator (text) {
    var option = document.createElement("option");
    option.innerHTML = `-------- ${text.toUpperCase()} --------`;
    option.disabled = true;

    this.menu.appendChild(option);
  }


  populateMenu(pops) {
    pops = pops.flat();
    this.createSelectMenu();
    var menuElems = this.createOptions(pops);
    this.displayMenu(menuElems);

  }


}
