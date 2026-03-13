import { LightningElement, wire, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import fetchBlogs from '@salesforce/apex/PortfolioBlogs.fetchPublishedBlogs';
import getCategoryPicklistValues from '@salesforce/apex/PortfolioBlogs.getPicklistValues';
import { getObjectInfo, getPicklistValues } from "lightning/uiObjectInfoApi";
import BLOG_OBJECT from '@salesforce/schema/Blog__c';
import CATEGORY from "@salesforce/schema/Blog__c.Category__c";

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

}