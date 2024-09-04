var garagesApp = new Vue({
  el: ".content",
  data: {
    show: false,

    startingPoint: 0,
    activeRotate: false,
    carHeading: 0,
    cameraPov: 60.0,
    inspect: false,
    topView: false,
    actionMenu: null,
    currentCarIndex: 0,
    currentCar: {
      name: "CHEVROLET CAMARO ZL1 1LE 2020",
      plate: "B 101 GHT",
      fuel: 10,
      engineHealth: 10,
      maxSpeed: { value: 300, percentage: 70 },
      acceleration: { value: 3.3, percentage: 45 },
      breaking: { value: 10.5, percentage: 45 },
      traction: { value: "Integrala", percentage: 45 },
    },
    cars: [],
    garageName: "Garaj Public",
  },
  methods: {
    async Post(url, data = {}) {
      const response = await fetch(
        `https://${GetParentResourceName()}/${url}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(data),
        }
      );

      return await response.json();
    },

    onMessage() {
      let data = event.data;

      switch (data.act) {
        case "open":
          this.show = true;
          this.cameraPov = 60.0;
          this.cars = data.playerCars;
          this.currentCar = this.cars[this.currentCarIndex];
          break;
        case "setHeading":
          this.carHeading = data.heading;
          break;
        default:
          break;
      }
    },
    onKey() {
      var theKey = event.code;
      if (theKey == "Escape") {
        this.closeUI();
        this.Post("ax_garages", { action: "closeUI" });
      }
    },
    closeUI() {
      this.show = false;
      this.actionMenu = null;
      this.topView = false;
      this.inspect = false;
      this.currentCarIndex = 0;
      this.cameraPov = 60.0;
      this.activeRotate = false;
    },
    showActionMenu() {
      this.actionMenu = !this.actionMenu;
      const wrapper = $(".car_name_wrapper");

      if (this.actionMenu) {
        wrapper.addClass("activ");
      } else {
        setTimeout(() => {
          wrapper.removeClass("activ");
        }, 1000);
      }
    },
    showTopView() {
      this.topView = !this.topView;
      const btn = $("#inspectVehicle");

      if (this.topView) btn.addClass("activ");
      else btn.removeClass("activ");

      this.Post("ax_garages", { action: "toggleTopView", state: this.topView });
    },
    toggleVehicleExtras() {
      this.inspect = !this.inspect;

      this.Post("ax_garages", {
        action: "toggleVehicleExtras",
        state: this.inspect,
      });
    },
    nextCar() {
      this.inspect = false;
      if (this.currentCarIndex == this.cars.length - 1) {
        this.currentCarIndex = 0;
      } else {
        this.currentCarIndex++;
      }

      this.currentCar = this.cars[this.currentCarIndex];

      this.Post("ax_garages", {
        action: "changeCar",
        model: this.currentCar.model,
        plate: this.currentCar.plate,
        engineHealth: this.currentCar.engineHealth,
      });
    },
    previousCar() {
      this.inspect = false;
      if (this.currentCarIndex == 0) {
        this.currentCarIndex = this.cars.length - 1;
      } else {
        this.currentCarIndex--;
      }

      this.currentCar = this.cars[this.currentCarIndex];

      this.Post("ax_garages", {
        action: "changeCar",
        model: this.currentCar.model,
        plate: this.currentCar.plate,
        engineHealth: this.currentCar.engineHealth,
      });
    },
    getVehicleOut() {
      this.Post("ax_garages", {
        action: "getVehicleOut",
        carData: {
          model: this.currentCar.model,
          plate: this.currentCar.plate,
          engineHealth: this.currentCar.engineHealth,
          fuel: this.currentCar.fuel,
          veh_type: this.currentCar.veh_type,
        },
      });
      this.closeUI();
    },
    handleScroll(event) {
      const delta = Math.max(
        -1,
        Math.min(1, event.wheelDelta || -event.detail)
      );

      if (delta > 0) {
        this.cameraPov = Math.max(16, this.cameraPov - 4);
      } else if (delta < 0) {
        this.cameraPov = Math.min(60, this.cameraPov + 4);
      }
      const formattedValue = this.cameraPov.toFixed(1);
      console.log("NEW POV: " + formattedValue);
      this.Post("ax_garages", { action: "changePov", value: formattedValue });
    },
    activateRotation(state, event) {
      this.activeRotate = state;
      this.startingPoint = event.pageX;
    },
    updateHeading(event) {
      if (!this.activeRotate) return;

      const x = event.pageX;
      this.carHeading = (x - this.startingPoint) / 10;

      this.startingPoint = x;
      this.Post("ax_garages", {
        action: "changeHeading",
        value: this.carHeading,
      });
    },
  },

  mounted() {
    window.addEventListener("message", this.onMessage);
    window.addEventListener("keydown", this.onKey);
    window.addEventListener("wheel", this.handleScroll);
  },
});
