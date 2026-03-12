import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import fetchBlogBySlug from '@salesforce/apex/PortfolioBlogs.fetchBlogBySlug';

export default class BlogDetailPage extends LightningElement {

    slug;
    detailedBlog;
    tags = [];
    hasBlogData = false;
    hasRenderedContent = false;

    // get hasBlogData() {
    //     console.log('Present = ', this.detailedeBlog);
    //     return this.detailedBlog;
    // }

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            const slug = currentPageReference.state?.slug;
            if (slug) {
                this.slug = slug;
                console.log('Slug from URL => ', this.slug);
            }
        }
    }

    @wire(fetchBlogBySlug, { slug: '$slug' })
    getClickedBlog({ error, data }) {
        if (data) {
            // const fetchedBlog = data[0];
            this.detailedBlog = data[0];
            if(this.detailedBlog) {
                this.hasBlogData = true;
            }
            this.tags = this.detailedBlog.tags?.split(';') || [];
            this.hasRenderedContent = false;
            console.log('Fetched Blog Data => ', JSON.stringify(this.detailedBlog));
            console.log('Fetched Blog Data => ', this.tags);
        }
    }

    get blog() {
        return this.detailedBlog || {};
    }

    renderedCallback() {
        if (this.hasRenderedContent || !this.detailedBlog?.content) {
            return;
        }

        const container = this.template.querySelector('.blog-content');
        if (container) {
            container.innerHTML = this.decodeHtml(this.detailedBlog.content);
            this.hasRenderedContent = true;
        }
    }

    decodeHtml(html) {
        const txt = document.createElement('textarea');
        txt.innerHTML = html;
        return txt.value;
    }

}