/*
creates and populates select populations menu for analysis tools.
*/

class OptionsMenu {
  constructor(elemId, elemClass, label) {
    elemId = elemId.replace(/#/, "");
    this.elemId = elemId;
    this.elemClass = elemClass || "form-control";
    this.label = label || "Select a population";
  }

  createOptionsMenu() {
    var menu = document.createElement("select");
    menu.id = this.elemId;
    menu.className = this.elemClass;

    var option = document.createElement("option");
    option.selected = this.label;
    option.value = this.label;
    option.innerHTML = this.label;

    menu.appendChild(option);

    return menu;
  }

  addOptions(data) {
    var menu = this.createOptionsMenu();

    var ids = [];
    data.forEach(function (dt) {
      if (!ids.includes(dt.id)) {
        var option = document.createElement("option");

        option.value = dt.id;
        option.dataset.pop = JSON.stringify(dt);
        option.innerHTML = dt.name;

        menu.appendChild(option);

        ids.push(dt.id);
      }
    });

    return menu;
  }
}
