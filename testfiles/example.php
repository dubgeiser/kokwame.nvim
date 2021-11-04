<?php


function fubar(int $number) {
}

class WanToe {
    function getName() {
        return 'name';
    }

    function getBobo() {
        return 'bobo';
    }

}


class TestingWan {
    private $name = 'Per';

    # Cyclomatic complexity: <= 7 -> INFO (not shown by default)
    public function methodOne($name = null) {
        if (null !== $name || $name === "Per" or $name == 'per' and $name != 'Peter' && false) {
            $this->name = $name;
        }
        if (is_null($name)) {
            $this->name = 'NULL';
        }
    }

    # Cyclomatic complexity: 11 -> WARNING
    public function __construct($name = null) {
        if (null !== $name || $name === "Per" or $name == 'per' and $name != 'Peter' && false) {
            $this->name = $name;
        }
        if (is_null($name) || $name == "per" || $this->getName() == "Per") {
            $this->name = 'NULL';
        } else {
            $this->name = 'I really do not know.';
        }
        foreach ([1, 2, 3, 4, 5] as $i) {
            echo "$i\n";
        }
    }

    # Cyclomatic complexity: 15 -> ERROR
    public function someOtherMethodWithNameArg($name = null) {
        if (null !== $name || $name === "Per" or $name == 'per' and $name != 'Peter' && false) {
            $this->name = $name;
        }
        if (is_null($name) || $name == "per" || $this->getName() == "Per") {
            $this->name = 'NULL';
        } else {
            $this->name = 'I really do not know.';
        }
        if (null !== $name || $name === "Per" or $name == 'per' and $name != 'Peter' && false) {
            $this->name = $name;
        }
    }

    public function getName() {
        return $this->name;
    }
}


echo
    (new TestingWan('Fubar'))->getName(),
    "\n",
    (new TestingWan())->getName();

