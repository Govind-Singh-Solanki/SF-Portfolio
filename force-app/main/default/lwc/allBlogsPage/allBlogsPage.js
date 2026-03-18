import { LightningElement, wire, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import fetchBlogs from '@salesforce/apex/PortfolioBlogs.fetchPublishedBlogs';
import getCategoryPicklistValues from '@salesforce/apex/PortfolioBlogs.getPicklistValues';
import subscribe from '@salesforce/apex/SubscriberController.subscribe';
import unsubscribe from '@salesforce/apex/SubscriberController.unsubscribe';
import checkStatus from '@salesforce/apex/SubscriberController.checkSubscriptionStatus';

// localStorage key
const LS_KEY = 'sf_blog_subscriber';

export default class AllBlogsPage extends NavigationMixin(LightningElement) {

    recordTypeId;
    allBlogs = [];
    filteredBlogs = [];
    visibleBlogs = [];
    isLoading = false;
    category = [];
    activeCategory = 'All';
    _rawCategories = [];
    
    blogsPerPage = 6;
    currentPage = 1;

    isModalOpen = false;
    showForm = true;
    showSuccess = false;
    isSubscribed = false;
    showUnsubscribeConfirm = false;
    showUnsubscribeSuccess = false;

    // Form fields
    formName  = '';
    formEmail = '';
    nameError  = '';
    emailError = '';
    errorMessage = '';

    submittedName = '';

    @wire(getCategoryPicklistValues)
    wiredCategoryValues({error, data}) {
        if (data) {
            console.log('Category Values => ', JSON.stringify(data));
            const picklistItems = data.map(item => ({
                label: item,
                value: item
            }));
            this._rawCategories = [{ label: 'All', value: 'All' }, ...picklistItems];
            this.buildAndSetPills();
            // console.log('Category 2 => ', this.category);
        } else if (error) {
            console.error(error);
        }
    }

    @wire(fetchBlogs)
    wiredBlogs({ error, data }) {
        if (data) {
            this.allBlogs = data;
            this.filteredBlogs = [...data];
            this.buildAndSetPills();
            // console.log('Blog Data => ', JSON.stringify(this.filteredBlogs));
            this.loadInitialBlogs();
        }
    }

    // loadInitialBlogs() {
    //     this.visibleBlogs = this.allBlogs.slice(0, this.blogsPerPage);
    // }

    connectedCallback() {
        this.readLocalStorage();
    }

    loadInitialBlogs() {
        this.visibleBlogs = this.filteredBlogs.slice(0, this.blogsPerPage);
    }

    // get hasBlogs() {
    //     return this.allBlogs.length > 0;
    // }

    get hasBlogs() {
        return this.visibleBlogs.length > 0;
    }

    // get hasMoreBlogs() {
    //     return this.visibleBlogs.length < this.allBlogs.length;
    // }

    get hasMoreBlogs() {
        return this.visibleBlogs.length < this.filteredBlogs.length;
    }

    get visibleCount() {
        return this.visibleBlogs.length;
    }

    // get totalCount() {
    //     return this.allBlogs.length;
    // }

    get totalCount() {
        return this.filteredBlogs.length;
    }

    get mobileButtonLabel() {
        return this.isSubscribed ? 'Unsubscribe' : 'Subscribe';
    }

    buildAndSetPills() {
        // Guard: don't run until raw categories are available
        if (!this._rawCategories || this._rawCategories.length === 0) return;
        this.category = this.buildPillObjects(this._rawCategories);
        // console.log('Category 2 => ', JSON.stringify(this.category));
    }

    buildPillObjects(rawCategories) {
        // console.log('Inside Built Pill => ', JSON.stringify(rawCategories));
        return rawCategories.map(cat => ({
            label: cat.label,
            value: cat.value,
            isActive: this.activeCategory === cat.value,
            count: cat.value === 'All'
                ? this.allBlogs.length
                : this.allBlogs.filter(b => b.category === cat.value).length,
            // pillClass: `pill ${this.activeCategory === cat.value ? 'pill--active' : ''} pill--${cat.value.toLowerCase().replace(/\s/g, '-')}`
            pillClass: `pill ${this.activeCategory === cat.value ? 'pill--active' : ''} pill--all`
        }));
    }

    handleCategoryClick(event) {
        const selected = event.currentTarget.dataset.value;
        if (selected === this.activeCategory) return;

        this.activeCategory = selected;
        this.category = this.buildPillObjects(this._rawCategories);

        // Filter from allBlogs into filteredBlogs
        this.filteredBlogs = selected === 'All'
            ? [...this.allBlogs]
            : this.allBlogs.filter(blog => blog.category === selected);
            // console.log('Clicked Category => ', this.filteredBlogs);

        // Reset pagination and slice first page
        this.currentPage = 1;
        this.visibleBlogs = this.filteredBlogs.slice(0, this.blogsPerPage);
        // console.log('Clicked Category => ', this.visibleBlogs);
    }

    handleOpenBlog(event) {
        const slug = event.currentTarget.dataset.slug;
        // console.log('Blog Slug => ', slug);
        if(!slug) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: `/blogs/blog?slug=${encodeURIComponent(slug)}`
            }
        });
    }

    loadMoreBlogs() {
        this.isLoading = true;
        
        // Simulate network delay for smooth UX
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this.currentPage++;
            const endIndex = this.currentPage * this.blogsPerPage;
            // this.visibleBlogs = this.allBlogs.slice(0, endIndex);
            this.visibleBlogs = this.filteredBlogs.slice(0, endIndex);
            this.isLoading = false;
        }, 500);
    }

    // ── localStorage helpers ──────────────────────────────────────────────
    readLocalStorage() {
        try {
            const raw = localStorage.getItem(LS_KEY);
            if (!raw) return;
            const data = JSON.parse(raw);
            if (data && data.isSubscribed && data.email && data.token) {
                this.isSubscribed = true;
                // Silently verify against Salesforce in background
                this.verifyStatusInBackground(data.email);
            }
        } catch (e) {
            // Corrupt storage — clear it
            localStorage.removeItem(LS_KEY);
        }
    }

    saveToLocalStorage(email, token) {
        try {
            localStorage.setItem(LS_KEY, JSON.stringify({
                email,
                token,
                isSubscribed: true
            }));
        } catch (e) {
            console.error('localStorage write failed:', e);
        }
    }

    clearLocalStorage() {
        try {
            localStorage.removeItem(LS_KEY);
        } catch (e) {
            console.error('localStorage clear failed:', e);
        }
    }

    getLocalData() {
        try {
            const raw = localStorage.getItem(LS_KEY);
            return raw ? JSON.parse(raw) : null;
        } catch (e) {
            return null;
        }
    }

    // ── Background verification ───────────────────────────────────────────
    verifyStatusInBackground(email) {
        checkStatus({ email })
            .then(status => {
                if (status !== 'ACTIVE') {
                    // They unsubscribed via another device or record was deleted
                    this.isSubscribed = false;
                    this.clearLocalStorage();
                }
            })
            .catch(() => {
                // Silently fail — keep localStorage state as fallback
            });
    }

    handleSubscription() {
        console.log('Status => ', this.isSubscribed)
        this.resetScreens();
        if (this.isSubscribed) {
            this.showForm = false;
            this.showUnsubscribeConfirm = true;
        } else {
            this.showForm = true;
        }
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
        this.resetForm();
        this.resetScreens();
    }

    handleBackdropClick(event) {
        if (event.target.classList.contains('modal-backdrop')) {
            this.closeModal();
        }
    }

    resetScreens() {
        this.showForm               = true;
        this.showSuccess            = false;
        this.showUnsubscribeConfirm = false;
        this.showUnsubscribeSuccess = false;
    }

    resetForm() {
        this.formName     = '';
        this.formEmail    = '';
        this.nameError    = '';
        this.emailError   = '';
        this.errorMessage = '';
    }

    // ── Form input handlers ───────────────────────────────────────────────
    handleNameInput(event) {
        this.formName  = event.target.value;
        this.nameError = '';
    }

    handleEmailInput(event) {
        this.formEmail  = event.target.value;
        this.emailError = '';
    }

    // ── Validation ────────────────────────────────────────────────────────
    validateForm() {
        let valid = true;

        if (!this.formName || this.formName.trim().length < 2) {
            this.nameError = 'Please enter your full name.';
            valid = false;
        }

        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!this.formEmail || !emailRegex.test(this.formEmail.trim())) {
            this.emailError = 'Please enter a valid email address.';
            valid = false;
        }

        return valid;
    }

    // ── Subscribe ─────────────────────────────────────────────────────────
    handleSubscribe() {
        this.errorMessage = '';
        if (!this.validateForm()) return;

        this.isLoading = true;
        this.submittedName = this.formName.trim();

        subscribe({ name: this.formName.trim(), email: this.formEmail.trim() })
            .then(token => {
                this.saveToLocalStorage(this.formEmail.trim().toLowerCase(), token);
                this.isSubscribed = true;
                this.isLoading    = false;
                this.showForm     = false;
                this.showSuccess  = true;
            })
            .catch(error => {
                this.isLoading    = false;
                const pageError = error?.body?.pageErrors?.[0]?.message;
                const bodyError = error?.body?.message;
                this.errorMessage = pageError || bodyError || 'Something went wrong. Please try again.';
                console.error('Subscribe error => ', error);
            });
    }

    // ── Unsubscribe ───────────────────────────────────────────────────────
    handleUnsubscribe() {
        const data = this.getLocalData();
        if (!data || !data.email || !data.token) {
            this.errorMessage = 'Could not verify your subscription. Please try again.';
            return;
        }

        this.isLoading = true;

        unsubscribe({ email: data.email, token: data.token })
            .then(() => {
                this.clearLocalStorage();
                this.isSubscribed           = false;
                this.isLoading              = false;
                this.showUnsubscribeConfirm = false;
                this.showUnsubscribeSuccess = true;
            })
            .catch(error => {
                this.isLoading    = false;
                this.errorMessage = error?.body?.message || 'Something went wrong. Please try again.';
            });
    }

    // ── Computed classes ──────────────────────────────────────────────────
    get navBtnClass() {
        return this.isSubscribed
            ? 'nav-subscribe-btn nav-subscribe-btn--active'
            : 'nav-subscribe-btn';
    }

    get nameInputClass() {
        return `field-input ${this.nameError ? 'field-input--error' : ''}`;
    }

    get emailInputClass() {
        return `field-input ${this.emailError ? 'field-input--error' : ''}`;
    }

}