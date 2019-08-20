'use strict';

const e = React.createElement;

class LikeButton extends React.Component {
    constructor(props) {
        super(props);
        this.state = { loggedIn: false };
    }

    render() {
        if (this.state.loggedIn) {
            return "You're logged in!";
        }

        return React.createElement("div", null, React.createElement("form", {
            id: "login_form",
            name: "login_form"
        }, React.createElement("div", {
            class: "container-fluid"
        }, React.createElement("input", {
            class: "form-control",
            style: {"width":"240px"},
            id: "username",
            name: "username",
            placeholder: "Username",
            type: "text"
        }), React.createElement("br", null), React.createElement("input", {
            class: "form-control",
            style: {"width":"240px"},
            id: "password",
            name: "password",
            placeholder: "Password",
            type: "password"
        }), React.createElement("br", null), React.createElement("div", {
            style: {"marginBottom":"40px"}
        }, React.createElement("a", {
            href: "/user/reset_password",
            style: {"float":"left"}
        }, "Forgot password?")), React.createElement("div", null, React.createElement("button", {
            class: "btn btn-secondary",
            id: "cancel_login",
            type: "reset",
            style: {"float":"left"}
        }, "Reset"), React.createElement("button", {
            class: "btn btn-primary",
            id: "submit_password",
            name: "submit_password",
            type: "submit",
            style: {"float":"right"}
        }, "Login")))));
    }
}

const domContainer = document.querySelector('#brapi-auth');
ReactDOM.render(e(LikeButton), domContainer);