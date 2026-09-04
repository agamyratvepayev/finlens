// Small progressive-enhancement helpers. The page is fully usable without JS.
(function () {
  'use strict';

  // Header border appears once the page is scrolled.
  var header = document.querySelector('[data-header]');
  if (header) {
    var onScroll = function () {
      header.classList.toggle('is-scrolled', window.scrollY > 8);
    };
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
  }

  // Mobile navigation toggle.
  var toggle = document.querySelector('[data-nav-toggle]');
  var mobileNav = document.querySelector('[data-mobile-nav]');
  if (toggle && mobileNav) {
    toggle.addEventListener('click', function () {
      var open = mobileNav.hasAttribute('hidden');
      if (open) {
        mobileNav.removeAttribute('hidden');
        mobileNav.style.display = 'flex';
      } else {
        mobileNav.setAttribute('hidden', '');
        mobileNav.style.display = 'none';
      }
      toggle.setAttribute('aria-expanded', String(open));
    });

    // Close the menu after tapping a link.
    mobileNav.querySelectorAll('a').forEach(function (link) {
      link.addEventListener('click', function () {
        mobileNav.setAttribute('hidden', '');
        mobileNav.style.display = 'none';
        toggle.setAttribute('aria-expanded', 'false');
      });
    });
  }
})();
