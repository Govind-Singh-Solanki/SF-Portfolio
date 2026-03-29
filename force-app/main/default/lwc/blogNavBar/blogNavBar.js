import { LightningElement } from 'lwc';

export default class BlogNavBar extends LightningElement {

    isMobileMenuOpen = false;
    isSearchOpen = false;
    searchQuery = '';
    currentPath = '';

    // Navigation items for blog pages
    navItemsData = [
        { id: 'home', label: 'Portfolio', href: '/', icon: 'utility:home' },
        { id: 'blogs', label: 'All Blogs', href: '/blog', icon: 'standard:article' },
        { id: 'categories', label: 'Categories', href: '/blog/categories', icon: 'utility:filterList' },
        { id: 'about', label: 'About', href: '/#about', icon: 'utility:user' }
    ];

    connectedCallback() {
        this.currentPath = window.location.pathname;
        this.handleResize = this.handleResize.bind(this);
        this.handleKeyDown = this.handleKeyDown.bind(this);
        window.addEventListener('resize', this.handleResize);
        window.addEventListener('keydown', this.handleKeyDown);
    }

    disconnectedCallback() {
        window.removeEventListener('resize', this.handleResize);
        window.removeEventListener('keydown', this.handleKeyDown);
    }

    get navItems() {
        return this.navItemsData.map(item => {
            const isActive = this.isActiveRoute(item.href);
            return {
                ...item,
                isActive,
                itemClass: `blog-nav-link ${isActive ? 'active' : ''}`,
                mobileItemClass: `blog-nav-mobile-link ${isActive ? 'active' : ''}`
            };
        });
    }

    isActiveRoute(href) {
        if (href === '/blog') {
            return this.currentPath === '/blog' || this.currentPath === '/blog/';
        }
        if (href === '/') {
            return this.currentPath === '/';
        }
        return this.currentPath.startsWith(href);
    }

    handleHomeClick(event) {
        // Allow default navigation to portfolio home
        this.isMobileMenuOpen = false;
    }

    handleNavClick(event) {
        const href = event.currentTarget.dataset.href;
        
        // For hash links on the same page
        if (href.includes('#') && !href.startsWith('/')) {
            event.preventDefault();
            const sectionId = href.split('#')[1];
            this.scrollToSection(sectionId);
        }
        
        this.isMobileMenuOpen = false;
    }

    handleSubscribeClick() {
        this.isMobileMenuOpen = false;
        // Dispatch event for subscribe action
        this.dispatchEvent(new CustomEvent('subscribe', {
            bubbles: true,
            composed: true
        }));
    }

    toggleMobileMenu() {
        this.isMobileMenuOpen = !this.isMobileMenuOpen;
        if (this.isMobileMenuOpen) {
            this.isSearchOpen = false;
        }
    }

    toggleSearch() {
        this.isSearchOpen = !this.isSearchOpen;
        if (this.isSearchOpen) {
            this.isMobileMenuOpen = false;
            // Focus input after render
            setTimeout(() => {
                const input = this.template.querySelector('.search-modal-input');
                if (input) input.focus();
            }, 100);
        }
    }

    closeSearch() {
        this.isSearchOpen = false;
        this.searchQuery = '';
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    handleSearchInput(event) {
        this.searchQuery = event.target.value;
        
        if (event.key === 'Enter' && this.searchQuery.trim()) {
            this.performSearch();
        } else if (event.key === 'Escape') {
            this.closeSearch();
        }
    }

    performSearch() {
        // Dispatch search event with query
        this.dispatchEvent(new CustomEvent('blogsearch', {
            detail: { query: this.searchQuery },
            bubbles: true,
            composed: true
        }));
        
        // Navigate to search results or filter
        window.location.href = `/blog?search=${encodeURIComponent(this.searchQuery)}`;
    }

    handleKeyDown(event) {
        // Cmd/Ctrl + K to open search
        if ((event.metaKey || event.ctrlKey) && event.key === 'k') {
            event.preventDefault();
            this.toggleSearch();
        }
        
        // Escape to close search
        if (event.key === 'Escape' && this.isSearchOpen) {
            this.closeSearch();
        }
    }

    scrollToSection(sectionId) {
        const section = document.querySelector(`[data-section="${sectionId}"]`);
        if (section) {
            section.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    }

    handleResize() {
        if (window.innerWidth >= 768 && this.isMobileMenuOpen) {
            this.isMobileMenuOpen = false;
        }
    }

}