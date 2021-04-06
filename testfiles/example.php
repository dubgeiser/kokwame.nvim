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

    public function __construct($name = null) {
        if (null !== $name) {
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

