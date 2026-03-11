import { LightningElement, wire, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import fetchBlogs from '@salesforce/apex/PortfolioBlogs.fetchPublishedBlogs';

export default class AllBlogsPage extends NavigationMixin(LightningElement) {

    allBlogs = [];
    visibleBlogs = [];
    isLoading = false;
    
    blogsPerPage = 6;
    currentPage = 1;

    @wire(fetchBlogs)
    wiredBlogs({ error, data }) {
        if (data) {
            this.allBlogs = data;
            // console.log('Blog Data => ', JSON.stringify(this.allBlogs));
            this.loadInitialBlogs();
        }
    }

    loadInitialBlogs() {
        this.visibleBlogs = this.allBlogs.slice(0, this.blogsPerPage);
    }

    get hasBlogs() {
        return this.allBlogs.length > 0;
    }

    get hasMoreBlogs() {
        return this.visibleBlogs.length < this.allBlogs.length;
    }

    get visibleCount() {
        return this.visibleBlogs.length;
    }

    get totalCount() {
        return this.allBlogs.length;
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
            this.visibleBlogs = this.allBlogs.slice(0, endIndex);
            this.isLoading = false;
        }, 500);
    }

}