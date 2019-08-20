'use strict';

const e = React.createElement;

class BrapiAuth extends React.Component {
    constructor(props) {
        super(props);
        this.state = {
            loggedIn: false,
            appName: props.appName,
            successUrl: props.successUrl,
            authToken: 'hello-world'
        };
    }

    render() {
        if (this.state.loggedIn) {
            return React.createElement("div", {
                className: "row"
            }, React.createElement("div", {
                className: "col-xs-12 col-md-4 col-md-offset-4"
            }, React.createElement("p", null, this.state.appName + " would like to access BreedBase on your behalf."), React.createElement("p", null, this.state.appName + " will be able to:"), React.createElement("ul", null, React.createElement("li", null, "Read data on your behalf"), React.createElement("li", null, "Write data on your behalf")), React.createElement("div", null, React.createElement("button", {
                className: "btn btn-default",
                id: "deny",
                style: {"float":"left"}
            }, "Deny"), React.createElement("button", {
                className: "btn btn-primary",
                id: "allow",
                name: "allow",
                style: {"float":"right"},
                onClick: () => window.location.replace(this.state.successUrl + this.state.authToken)
            }, "Allow"))));
        }

        return React.createElement("div", {
            className: "row"
        }, React.createElement("form", {
            id: "login_form",
            name: "login_form"
        }, React.createElement("div", {
            className: "col-xs-12 col-md-4 col-md-offset-4"
        }, React.createElement("p", null, this.state.appName + " would like to access BreedBase on your behalf"), React.createElement("input", {
            className: "form-control",
            id: "username",
            name: "username",
            placeholder: "Username",
            type: "text"
        }), React.createElement("br", null), React.createElement("input", {
            className: "form-control",
            id: "password",
            name: "password",
            placeholder: "Password",
            type: "password"
        }), React.createElement("div", {
            style: {"marginBottom":"40px"}
        }, React.createElement("a", {
            href: "/user/reset_password",
            style: {"float":"left"}
        }, "Forgot password?")), React.createElement("div", null, React.createElement("button", {
            className: "btn btn-secondary",
            id: "cancel_login",
            type: "reset",
            style: {"float":"left"}
        }, "Reset"), React.createElement("button", {
            className: "btn btn-primary",
            id: "submit_password",
            name: "submit_password",
            type: "submit",
            style: {"float":"right"},
            onClick: () => this.setState({
                loggedIn: true
            })
        }, "Login")))));
    }
}