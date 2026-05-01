// ===== NAV =====
const nav = document.getElementById('nav');
const hamburger = document.getElementById('hamburger');
const mobileMenu = document.getElementById('mobile-menu');
const hamOpen = document.getElementById('ham-open');
const hamClose = document.getElementById('ham-close');
let menuOpen = false;

if (nav) {
  window.addEventListener('scroll', () => {
    nav.classList.toggle('scrolled', window.scrollY > 20);
  }, { passive: true });
}

if (hamburger && mobileMenu) {
  hamburger.addEventListener('click', () => {
    menuOpen = !menuOpen;
    mobileMenu.classList.toggle('open', menuOpen);
    if (hamOpen)  hamOpen.style.display  = menuOpen ? 'none'  : 'block';
    if (hamClose) hamClose.style.display = menuOpen ? 'block' : 'none';
  });
  mobileMenu.querySelectorAll('a').forEach(link => {
    link.addEventListener('click', () => {
      menuOpen = false;
      mobileMenu.classList.remove('open');
      if (hamOpen)  hamOpen.style.display  = 'block';
      if (hamClose) hamClose.style.display = 'none';
    });
  });
}

// ===== SCREENSHOTS CAROUSEL =====
const items = document.querySelectorAll('.screenshot-item');
const dots  = document.querySelectorAll('.carousel-dot');
const prevBtn = document.getElementById('prev-btn');
const nextBtn = document.getElementById('next-btn');
let activeIndex = 0;

function updateCarousel(scroll) {
  items.forEach((el, i) => {
    el.classList.toggle('active', i === activeIndex);
    if (scroll && i === activeIndex) {
      el.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'center' });
    }
  });
  dots.forEach((d, i) => d.classList.toggle('active', i === activeIndex));
  if (prevBtn) prevBtn.disabled = activeIndex === 0;
  if (nextBtn) nextBtn.disabled = activeIndex === items.length - 1;
}

if (items.length > 0) {
  updateCarousel(false); // initial — no scroll
  if (prevBtn) prevBtn.addEventListener('click', () => { if (activeIndex > 0) { activeIndex--; updateCarousel(true); } });
  if (nextBtn) nextBtn.addEventListener('click', () => { if (activeIndex < items.length - 1) { activeIndex++; updateCarousel(true); } });
  dots.forEach((d, i) => d.addEventListener('click', () => { activeIndex = i; updateCarousel(true); }));
  items.forEach((el, i) => el.addEventListener('click', () => { activeIndex = i; updateCarousel(true); }));
}

// ===== CONTACT FORM =====
const contactForm    = document.getElementById('contact-form');
const contactSuccess = document.getElementById('contact-success');
const contactError   = document.getElementById('contact-error');
const contactSubmit  = document.getElementById('contact-submit');

if (contactForm) {
  contactForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    if (contactError) contactError.style.display = 'none';
    const orig = contactSubmit.innerHTML;
    contactSubmit.disabled = true;
    contactSubmit.innerHTML = `<svg class="animate-spin" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 12a9 9 0 1 1-6.219-8.56"/></svg> Sending…`;
    try {
      const res = await fetch('https://formspree.io/f/xrerygky', {
        method: 'POST',
        body: new FormData(contactForm),
        headers: { 'Accept': 'application/json' }
      });
      if (res.ok) {
        contactForm.style.display = 'none';
        if (contactSuccess) contactSuccess.style.display = 'flex';
      } else { throw new Error(); }
    } catch {
      if (contactError) contactError.style.display = 'block';
      contactSubmit.disabled = false;
      contactSubmit.innerHTML = orig;
    }
  });
}

const contactReset = document.getElementById('contact-reset');
if (contactReset && contactForm && contactSuccess) {
  contactReset.addEventListener('click', () => {
    contactForm.reset();
    contactForm.style.display = 'block';
    contactSuccess.style.display = 'none';
  });
}

// ===== NOTIFY FORM =====
const notifyForm    = document.getElementById('notify-form');
const notifySuccess = document.getElementById('notify-success');
const notifyBtn     = document.getElementById('notify-btn');

if (notifyForm) {
  notifyForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    notifyBtn.disabled = true;
    notifyBtn.innerHTML = `<svg class="animate-spin" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83"/></svg>`;
    try {
      await fetch('https://formspree.io/f/xrerygky', {
        method: 'POST',
        body: new FormData(notifyForm),
        headers: { 'Accept': 'application/json' }
      });
    } catch {}
    // Always show success (same as original Next.js behaviour)
    notifyForm.style.display = 'none';
    if (notifySuccess) notifySuccess.style.display = 'flex';
  });
}
