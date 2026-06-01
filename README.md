# Black Silva Hairdresser — 3D Booking Experience

An interactive, scroll-driven 3D website for **Black Silva Hairdresser** (Copenhagen, Badstuestræde 16).
Walk into the studio, sign in, and complete a full booking — all rendered in real time with Three.js.

Built as a **single self-contained `index.html`** (the hairstyle reference images are inlined), so it
runs anywhere and deploys to GitHub Pages with zero build step.

## ✨ Experience flow

1. **Scroll in** — the customer walks from the dark street into the salon as the world brightens from night to day.
2. **Sign in** — a login / sign-up gate. You must log in to continue.
3. **Hair length** — the chair swivels, the camera pushes to a close-up, and a glass menu lets you pick your current length (with reference images).
4. **Service** — Fade · Scissors cut · Beard trim.
5. **Date & time** — pick from the next 14 days and an available slot.
6. **Stylist** — choose **Eduard** or **Elena**; they walk over and give you a cut.
7. **Confirmed** — a few seconds of suspense behind the stylist, then a fresh new look: you enter with **afro hair** and leave with a **short fade**, while the stylist celebrates with a left-hand dance. ✅

## 🚀 Run it

Just open `index.html` in any modern browser — no server or build needed.

### Deploy on GitHub Pages
1. Push this folder to a GitHub repo.
2. **Settings → Pages → Source: `main` / root**.
3. Your site goes live at `https://<user>.github.io/<repo>/`.

## 🧱 Tech stack
- [Three.js r128](https://threejs.org/) — real-time WebGL scene (orthographic / isometric)
- [GSAP + ScrollTrigger](https://greensock.com/) — scroll storytelling & animation
- Vanilla JS, custom CSS (Manrope + Cormorant Garamond)

> Three.js & GSAP load from the cdnjs CDN, so an internet connection is required at runtime.

## 📂 Structure
```
black-silva-hairdresser/
├── index.html      # the entire website (3D scene + booking flow + inlined images)
├── README.md
├── LICENSE
└── .gitignore
```

## 📄 License
MIT — see [LICENSE](LICENSE).
