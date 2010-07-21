use MooseX::Declare;

class SGN::View::Feature {
    method render($c,$name) {
        return "Render feature $name\n";
    }

}
