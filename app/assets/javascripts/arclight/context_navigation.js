class ContextNavigation {
  constructor(el) {
    this.el = $(el);
    this.data = this.el.data();
    this.parentLi = this.el.parent();
  }
  
  static placeholder() {
    const placeholder = '<div class="al-hierarchy-placeholder">' +
                          '<h3 class="col-md-9"></h3>' +
                          '<p class="col-md-6"></p>' +
                          '<p class="col-md-12"></p>' +
                          '<p class="col-md-3"></p>' +
                        '</div>';
    return new Array(3).join(placeholder);
  }

  getData() {
    const that = this;
    // Add a placeholder so flashes of text are not as significant
    this.el.after(ContextNavigation.placeholder());
    $.ajax({
      url: this.data.arclight.path,
      data: {
        'f[component_level_isim][]': this.data.arclight.level,
        'f[has_online_content_ssim][]': this.data.arclight.access,
        'f[collection_sim][]': this.data.arclight.name,
        'f[parent_ssi][]': this.data.arclight.parent,
        search_field: this.data.arclight.search_field,
        view: 'collection_context'
      }
    }).done(function (response) {
      var resp = $.parseHTML(response);
      var $doc = $(resp);
      var newDocs = $doc.find('#documents')
        .find('article')
        .toArray().map(el => new NavigationDocument(el).render());

      const docIndex = newDocs.findIndex(doc => doc.id === that.data.arclight.parentsParent)
      console.log(docIndex, that.data.arclight);

      that.parentLi.find('.al-hierarchy-placeholder').remove();
      that.parentLi.before(newDocs.join('')).fadeIn(500);
      // that.el.hide().html(newDocs.join('')).fadeIn(500);
    });
  }
}

class NavigationDocument {
  constructor(el) {
    this.el = $(el);
  }
  
  id() {
    return this.el.find('[data-document-id]').data().documentId;
  }

  render() {
    return this.el.html();
  }
}


Blacklight.onLoad(function () {

  $('.context-navigator').each(function (i, e) {
    const contextNavigation = new ContextNavigation(e);
    contextNavigation.getData();
  });
});
