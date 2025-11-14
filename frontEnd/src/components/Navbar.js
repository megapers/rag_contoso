import React, { useState, useCallback } from 'react';
import { Link, useLocation } from 'react-router-dom';
import './Navbar.css';

function Navbar() {
  const location = useLocation();
  const [menuOpen, setMenuOpen] = useState(false);

  const toggleMenu = useCallback(() => {
    setMenuOpen((prev) => !prev);
  }, []);

  const closeMenu = useCallback(() => {
    setMenuOpen(false);
  }, []);

  const handleKeyDown = useCallback(
    (event) => {
      if (event.key === 'Escape') {
        setMenuOpen(false);
      }
    },
    []
  );

  const isActive = useCallback(
    (path) => (location.pathname === path ? 'active' : ''),
    [location.pathname]
  );

  return (
    <nav className="app-navbar" onKeyDown={handleKeyDown}>
      <Link to="/" className="navbar-brand" onClick={closeMenu}>
        <span className="brand-logo">Contoso RAG</span>
        <span className="brand-tagline">Sales insights, powered by AI</span>
      </Link>

      <button
        className={`navbar-toggle ${menuOpen ? 'open' : ''}`}
        aria-expanded={menuOpen}
        aria-controls="navbar-menu"
        aria-label={menuOpen ? 'Close menu' : 'Open menu'}
        type="button"
        onClick={toggleMenu}
      >
        <span></span>
        <span></span>
        <span></span>
      </button>

      <div className={`navbar-overlay ${menuOpen ? 'open' : ''}`} onClick={closeMenu} />

      <div
        className={`navbar-menu ${menuOpen ? 'open' : ''}`}
        id="navbar-menu"
        role="dialog"
        aria-modal="true"
        aria-hidden={!menuOpen}
      >
        <nav className="menu-links" aria-label="Primary">
          <Link to="/" className={`menu-link ${isActive('/')}`} onClick={closeMenu}>
            Home
          </Link>
          <Link to="/about" className={`menu-link ${isActive('/about')}`} onClick={closeMenu}>
            About
          </Link>
        </nav>

        <div className="menu-divider" role="presentation"></div>

        <div className="menu-footer">
          <p className="menu-footer-heading">Built by Timur Makimov</p>
          <p className="menu-footer-copy">
            Software developer focused on pragmatic AI solutions for modern cloud platforms.
          </p>
          <div className="menu-social">
            <a href="https://www.linkedin.com/in/timur-makimov-67703512/" target="_blank" rel="noopener noreferrer" onClick={closeMenu}>
              LinkedIn
            </a>
            <a href="https://github.com/megapers/" target="_blank" rel="noopener noreferrer" onClick={closeMenu}>
              GitHub
            </a>
          </div>
        </div>
      </div>
    </nav>
  );
}

export default Navbar;
