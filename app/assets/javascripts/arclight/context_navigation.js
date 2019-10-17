var contextNavigators = [];

class NavigationDocument {
  constructor(el) {
    this.el = $(el);
  }

  get id() {
    return this.el.find('[data-document-id]').data().documentId;
  }

  setAsHighlighted() {
    this.el.find('li.al-collection-context').addClass('al-hierarchy-highlight');
  }

  collapse() {
    this.el.find('li.al-collection-context').addClass('collapsed');
  }

  render() {
    return this.el.html();
  }
}

/**
 * Models the "Expand"/"Collapse" button, and provides an onClick event handler
 * for the jQuery element
 * @class
 */
class ExpandButton {
  /**
   * This retrieves the <li> elements which are hidden/rendered in response to
   *   clicking the <button> element
   * @param {jQuery} $li - the <button> element
   * @return {jQuery} - a jQuery object containing the targeted <li>
   */
  findSiblings() {
    const $siblings = this.$el.parent().children('li');
    return $siblings.slice(0, -1);
  }

  /**
   * This adds a "collapsed" class to all of the <li> children, as well as
   *   updates the text for the <button> element
   * @param {Event} event - the event propagated in response to clicking on the
   *   <button> element
   */
  handleClick() {
    const $targeted = this.$el.prevAll('li');

    $targeted.toggleClass('collapsed');
    this.$el.toggleClass('collapsed');

    const containerText = this.$el.hasClass('collapsed') ? this.collapseText : this.expandText;
    this.$el.text(containerText);
  }

  /**
   * @constructor
   */
  constructor() {
    const collapseParent = $('.al-collapse-parent');
    this.collapseText = collapseParent[0].dataset.collapse;
    this.expandText = collapseParent[0].dataset.expand;

    this.$el = $(`<button class="my-3 btn btn-secondary btn-sm">${this.expandText}</button>`);
    this.handleClick = this.handleClick.bind(this);
    this.$el.click(this.handleClick);
  }
}

/**
 * Modeling <button> Elements which hide or retrieve <li> elements for sibling
 *   documents nested within the <li> elements of the <ul> tree
 * @class
 */
class NestedExpandButton extends ExpandButton {
  /**
   * This retrieves the <li> elements which are hidden/rendered in response to
   *   clicking the <button> element
   * @param {jQuery} $li - the <button> element
   * @return {jQuery} - a jQuery object containing the targeted <li>
   */
  findSiblings() {
    const highlighted = this.$el.siblings('.al-hierarchy-highlight');
    const $siblings = highlighted.prevAll('.al-collection-context');
    return $siblings.slice(0, -1);
  }
}

/**
 * Models the placeholder display elements for content loading from AJAX
 *   requests
 * @class
 */
class Placeholder {
  /*
   * Builds the element set which contains the placeholder markup
   *   classes
   */
  /* eslint-disable class-methods-use-this */
  buildElement() {
    const elementMarkup = '<div class="al-hierarchy-placeholder">' +
      '<h3 class="col-md-9"></h3>' +
      '<p class="col-md-6"></p>' +
      '<p class="col-md-12"></p>' +
      '<p class="col-md-3"></p>' +
      '</div>';
    const markup = Array(3).join(elementMarkup);

    return $(markup);
  }
  /* eslint-enable class-methods-use-this */

  /*
   * @constructor
   */
  constructor() {
    this.$el = this.buildElement();
  }
}

class ContextNavigation {
  constructor(el) {
    this.el = $(el);
    this.data = this.el.data();
    this.parentLi = this.el.parent();
    this.loaded = false;
    contextNavigators.push(this);
  }

  static existsForElement(el) {
    let existing = contextNavigators.find(e => {
      return e.data.arclight.originalDocument === $(el).data().arclight.originalDocument &&
        e.data.arclight.level === $(el).data().arclight.level;
    });
    return existing;
  }

  static newForElement(el) {
    let existing = ContextNavigation.existsForElement(el);
    if (existing != null) {
      return existing;
    }
    return new ContextNavigation(el);
  }

  getData() {
    const that = this;
    if (this.loaded) {
      return;
    }
    // Add a placeholder so flashes of text are not as significant
    const placeholder = new Placeholder();
    this.el.after(placeholder.$el);

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
    }).done((response) => that.updateView(response));
    this.loaded = true;
  }

  /**
   * Constructs a <ul> container element with an ElementButton instance appended
   * within it
   * @returns {jQuery}
   */
  /* eslint-disable class-methods-use-this */
  buildExpandList() {
    const $ul = $('<ul></ul>');
    $ul.addClass('pl-0');
    $ul.addClass('prev-siblings');
    const button = new ExpandButton();
    $ul.append(button.$el);
    return $ul;
  }
  /* eslint-enable class-methods-use-this */

  /**
   * Highlights the <li> element for the current Document and appends <li> the
   *   sibling documents for a given Document element
   * @param {NavigationDocument[]} newDocs - the NavigationDocument objects for
   *   each resulting Solr Document
   * @param {number} originalDocumentIndex
   * @param {jQuery} parentLi
   */
  updateSiblings(newDocs, originalDocumentIndex, parentLi) {
    newDocs[originalDocumentIndex].setAsHighlighted();

    // Hide all but the first previous sibling
    const prevSiblingDocs = newDocs.slice(0, originalDocumentIndex);
    let nextSiblingDocs = [];

    if (prevSiblingDocs.length > 1 && originalDocumentIndex > 0) {
      const hiddenPrevSiblingDocs = prevSiblingDocs.slice(0, -1);
      hiddenPrevSiblingDocs.forEach(siblingDoc => {
        siblingDoc.collapse();
      });

      const prevSiblingList = this.buildExpandList();
      const renderedPrevSiblingItems = prevSiblingDocs.map(doc => doc.render()).join('');

      prevSiblingList.append(renderedPrevSiblingItems);
      parentLi.before(prevSiblingList);

      nextSiblingDocs = newDocs.slice(originalDocumentIndex);
    } else {
      nextSiblingDocs = newDocs;
    }

    const renderedNextSiblingItems = nextSiblingDocs.map(newDoc => newDoc.render()).join('');

    // Insert the rendered sibling documents before the <li> elements
    parentLi.before(renderedNextSiblingItems).fadeIn(500);
  }

  /**
   * Inserts <li> elements for parents (e. g. components or collections) for the
   *   current Document and appends <li> for each of these
   * @param {NavigationDocument[]} newDocs - the NavigationDocument objects for
   *   each resulting Solr Document
   * @param {string[]} originalParents - the IDs for the Solr Documents of each
   *   ancestor
   * @param {string} parent - the ID for the immediate parent (ancestor)
   * @param {jQuery} parentLi - the <li> used to generate the <ul> for the
   * context - this is consistently the *last* element in the <ul>
   */
  updateParents(newDocs, originalParents, parent, parentLi) {
    // Case where this is a parent list and needs to be filed correctly
    //
    // Otherwise, retrieve the parent...
    const parentIndex = originalParents.indexOf(parent);

    // The first parent is always used to consistently construct the doc ID
    const firstParent = originalParents[0];
    const nextParent = originalParents[parentIndex + 1];
    const currentId = `${firstParent}${nextParent}`;

    const newDocIndex = newDocs.findIndex(doc => doc.id === currentId);

    // Update the docs before the item
    // Retrieves the documents up to and including the "new document"
    const beforeDocs = newDocs.slice(0, newDocIndex);
    let renderedBeforeDocs;
    if (beforeDocs.length > 1) {
      beforeDocs.forEach(function (parentDoc) {
        parentDoc.collapse();
      });
      renderedBeforeDocs = beforeDocs.map(newDoc => newDoc.render()).join('');
      const prevParentList = this.buildExpandList();
      prevParentList.append(renderedBeforeDocs);
    } else {
      renderedBeforeDocs = beforeDocs.map(newDoc => newDoc.render()).join('');
    }

    parentLi.before(renderedBeforeDocs).fadeIn(500);

    let itemDoc = newDocs.slice(newDocIndex, newDocIndex + 1);
    let renderedItemDoc = itemDoc.map(doc => doc.render()).join('');

    // Update the item
    const $itemDoc = $(renderedItemDoc);
    // Update the id, add classes of the classes. Prepend the current children.
    parentLi.attr('id', $itemDoc.attr('id'));
    parentLi.addClass($itemDoc.attr('class'));

    parentLi.prepend($itemDoc.children()).fadeIn(500);

    // Update the docs after the item
    const afterDocs = newDocs.slice(newDocIndex + 1, newDocs.length);
    const renderedAfterDocs = afterDocs.map(newDoc => newDoc.render()).join('');

    // Insert the documents after the current
    parentLi.after(renderedAfterDocs).fadeIn(500);
  }

  /**
   * Update the ancestors for <li> elements
   * @param {jQuery} $li - the <li> element for the current, highlighted
   *   Document in the <ul> context list of collections, components, and
   *   containers
   */
  /* eslint-disable class-methods-use-this */
  updateListSiblings($li) {
    const prevSiblings = $li.prevAll('.al-collection-context');
    if (prevSiblings.length > 1) {
      const hiddenNextSiblings = prevSiblings.slice(0, -1);
      hiddenNextSiblings.toggleClass('collapsed');

      const button = new NestedExpandButton();

      const lastHiddenNextSibling = hiddenNextSiblings[hiddenNextSiblings.length - 1];
      button.$el.insertAfter(lastHiddenNextSibling);
    }
  }
  /* eslint-enable class-methods-use-this */

  /**
   * This updates the elements in the View DOM using an AJAX response containing
   *   the HTML of a server-rendered View template.
   * It is this which is primarily used to populate the <ul> element with
   *   children for the navigation context, containing <li> elements for
   *   collections, components, and containers.
   * @param {string} response - the AJAX response body
   */
  updateView(response) {
    const that = this;
    var resp = $.parseHTML(response);
    var $doc = $(resp);
    var newDocs = $doc.find('#documents')
      .find('article')
      .toArray().map(el => new NavigationDocument(el));

    // Filter for only the <article> element which encodes the information for
    // the child or parent Solr Document
    const originalDocumentIndex = newDocs
      .findIndex(doc => doc.id === that.data.arclight.originalDocument);
    that.parentLi.find('.al-hierarchy-placeholder').remove();

    if (originalDocumentIndex !== -1) {
      this.updateSiblings(newDocs, originalDocumentIndex, that.parentLi);
    } else {
      this.updateParents(
        newDocs,
        that.data.arclight.originalParents,
        that.data.arclight.parent,
        that.parentLi
      );
    }
    that.truncateItems();
    Blacklight.doBookmarkToggleBehavior();
    $('.al-toggle-view-children').click((e) => {
      e.preventDefault();
      let context = $(e.target).closest('.al-collection-context');
      let id = context[0].id;
      let expandable = context.find('#' + id + '-collapsible-hierarchy');
      if (expandable != null && expandable.length === 1) {
        let expandableContents = expandable.find('.al-contents');
        if (expandableContents != null) {
          const navigator = ContextNavigation.newForElement(expandableContents[0]);
          navigator.getData();
        }
      }
    });

    // Select the <li> element for the current document
    const highlighted = that.parentLi.siblings('.al-hierarchy-highlight');
    this.updateListSiblings(highlighted);
  }

  /* eslint-disable class-methods-use-this */
  truncateItems() {
    $('[data-arclight-truncate="true"]').each(function (_, el) {
      $(el).responsiveTruncate({
        more: el.dataset.truncateMore,
        less: el.dataset.truncateLess
      });
    });
  }
  /* eslint-enable class-methods-use-this */
}

/**
 * Integrate the behavior into the DOM using the Blacklight#onLoad callback
 *
 */
Blacklight.onLoad(function () {
  let hierarchyElements = $('.al-hierarchy-element');
  hierarchyElements.each((index, element) => {
    // This list will be in reverse order, counting up from the target element
    let prevSiblings = $(element).prevAll('li');
    if (prevSiblings.length > 1) {
      const hiddenNextSiblings = prevSiblings.slice(1);
      hiddenNextSiblings.toggleClass('collapsed');

      const button = new ExpandButton();

      const lastHiddenNextSibling = hiddenNextSiblings[0];
      button.$el.insertAfter(lastHiddenNextSibling);
    }
  });
  $('.context-navigator').each(function (i, e) {
    const contextNavigation = ContextNavigation.newForElement(e);
    contextNavigation.getData();
  });
});
