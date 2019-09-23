function readonly(target, name, descriptor) {
    descriptor.writable = false;
    return descriptor;
}

class Foo {
  constructor(el) {
    this.el = el;
  }

  @readonly
  bar() {}
};

Blacklight.onLoad(() => {
  'use strict';

  window.foo = new(Foo, window.document);
  window.foo.bar = 'forbidden by the decorator';
});
