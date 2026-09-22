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

    option.value = this.getOptionValue(dt);
    option.dataset.pop = JSON.stringify(dt);
    option.innerHTML = dt.name;

    return option;

  }

  getOptionValue(dt) {
    return dt.menu_id || dt.id;
  }

  createOptions(data) {
    var menu = this.menu;
    if (!menu) {
      menu = this.createSelectMenu();
    }

    data.forEach((dt) => {
        if (dt && !this.hasOption(menu.options, this.getOptionValue(dt))) {
            const option = this.createOptionElement(dt);
            menu.appendChild(option);
        }
    });

    return menu;
  }

  hasOption(options, value) {
    return Array.from(options).some(function (option) {
      return option.value === String(value);
    });
  }

  updateOptions(newPop) {
    var options = this.getSelectMenuOptions();
    if (
      options &&
      newPop &&
      !this.hasOption(options, this.getOptionValue(newPop))
    ) {
      var newOption = this.createOptionElement(newPop);
      options.add(newOption);
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
