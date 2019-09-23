
class Foo {
  constructor(el) {
    this.el = el;
  }

  @readonly(false)
  bar() {}
};

function readonly(value) {
  return function (target) {
    // This departs from the example given on https://babeljs.io/docs/en/babel-plugin-proposal-decorators
    // I do not know why this is the case
    const descriptor = target.descriptor;
    descriptor.writable = value;
    return target;
  }
};

Blacklight.onLoad(() => {
  'use strict';

  window.foo = new Foo(window.document);
  window.foo.bar = 'forbidden by the decorator';
});
