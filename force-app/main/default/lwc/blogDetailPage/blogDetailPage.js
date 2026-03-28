import { LightningElement, wire, track } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import fetchBlogBySlug   from '@salesforce/apex/PortfolioBlogs.fetchBlogBySlug';
import fetchRelatedBlogs from '@salesforce/apex/PortfolioBlogs.fetchRelatedBlogs';
import PORTFOLIO_ASSETS  from '@salesforce/resourceUrl/Portfolio_Assets';

export default class BlogDetailPage extends NavigationMixin(LightningElement) {

    // ── State ─────────────────────────────────────────────────────────────
    slug;
    detailedBlog;
    relatedBlogs     = [];
    tags             = [];
    hasBlogData      = false;

    copyLinkLabel   = 'Copy Link';
    showMobileShare = false;

    authorPhoto = PORTFOLIO_ASSETS + '/Portfolio_Assets/Govind_Singh_Solanki.png';

    // ── URL state ─────────────────────────────────────────────────────────
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            const slug = currentPageReference.state?.slug;
            if (slug && slug !== this.slug) {
                this.slug           = slug;
                this.hasBlogData    = false;
                this.showMobileShare = false;
            }
        }
    }

    // ── Fetch blog ────────────────────────────────────────────────────────
    @wire(fetchBlogBySlug, { slug: '$slug' })
    getClickedBlog({ error, data }) {
        if (data && data[0]) {
            // console.log('BLOG DATA -> ', data);
            this.detailedBlog = data[0];
            this.hasBlogData  = true;
            console.log('DEBUG: Full blog object =>', JSON.stringify(this.detailedBlog));
            console.log('DEBUG: Content field =>', this.detailedBlog.content);
            this.tags = this.detailedBlog.tags
                ? this.detailedBlog.tags.split(';').map(t => t.trim()).filter(Boolean)
                : [];
            this.loadRelatedBlogs();
        } else if (error) {
            console.error('fetchBlogBySlug error =>', error);
        }
    }

    // ── Fetch related blogs ───────────────────────────────────────────────
    loadRelatedBlogs() {
        if (!this.detailedBlog?.id || !this.detailedBlog?.category) return;
        fetchRelatedBlogs({
            blogId:   this.detailedBlog.id,
            category: this.detailedBlog.category
        })
        .then(data => { this.relatedBlogs = data || []; })
        .catch(err  => console.error('fetchRelatedBlogs error =>', err));
    }

    // ── Content blocks getter — parses JSON into typed block objects ───────
    get contentBlocks() {
        if (!this.detailedBlog?.content) {
            console.log('DEBUG: No content found on detailedBlog');
            return [];
        }
        try {
            console.log('DEBUG: Raw content =>', this.detailedBlog.content);
            const blocks = JSON.parse(this.detailedBlog.content);
            console.log('DEBUG: Parsed blocks =>', JSON.stringify(blocks));
            return blocks.map((block, index) => ({
                ...block,
                key:            index,
                isParagraph:    block.type === 'paragraph',
                isHeading:      block.type === 'heading',   // renders as h3
                isHeading2:     block.type === 'heading2',  // renders as h2
                isBullets:      block.type === 'bullets',   // items: [{term, description}]
                isSimpleBullets:block.type === 'simple-bullets', // items: ['string', ...]
                isNumbered:     block.type === 'numbered',  // items: ['string', ...]
                isQuote:        block.type === 'quote',
                isCode:         block.type === 'code',
            }));
        } catch (e) {
            console.error('DEBUG: JSON parse error =>', e.message);
            console.log('DEBUG: Content that failed =>', this.detailedBlog.content);
            return [];
        }
    }

    // ── Read time — counts words across all block content ─────────────────
    get readTime() {
        if (!this.detailedBlog?.content) return 1;
        try {
            const blocks = JSON.parse(this.detailedBlog.content);
            const allText = blocks.map(b => {
                if (b.items) {
                    return Array.isArray(b.items)
                        ? b.items.map(i => (typeof i === 'string' ? i : `${i.term || ''} ${i.description || ''}`)).join(' ')
                        : '';
                }
                return b.content || '';
            }).join(' ');
            const wordCount = allText.trim().split(/\s+/).length;
            return Math.max(1, Math.ceil(wordCount / 100));
        } catch (e) {
            return 1;
        }
    }

    // ── Share handlers ────────────────────────────────────────────────────
    toggleMobileShare() {
        this.showMobileShare = !this.showMobileShare;
    }

    copyLink() {
        const url = window.location.href;
        navigator.clipboard.writeText(url)
            .then(() => {
                this.copyLinkLabel   = 'Copied!';
                this.showMobileShare = false;
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => { this.copyLinkLabel = 'Copy Link'; }, 2500);
            })
            .catch(() => {
                const el = document.createElement('input');
                el.value = url;
                document.body.appendChild(el);
                el.select();
                document.execCommand('copy');
                document.body.removeChild(el);
                this.copyLinkLabel   = 'Copied!';
                this.showMobileShare = false;
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => { this.copyLinkLabel = 'Copy Link'; }, 2500);
            });
    }

    shareLinkedIn() {
        const url = encodeURIComponent(window.location.href);
        window.open(`https://www.linkedin.com/sharing/share-offsite/?url=${url}`, '_blank');
        this.showMobileShare = false;
    }

    shareWhatsApp() {
        const url   = encodeURIComponent(window.location.href);
        const title = encodeURIComponent(this.detailedBlog?.title || '');
        window.open(`https://wa.me/?text=${title}%20${url}`, '_blank');
        this.showMobileShare = false;
    }

    shareTwitter() {
        const url   = encodeURIComponent(window.location.href);
        const title = encodeURIComponent(this.detailedBlog?.title || '');
        window.open(`https://x.com/intent/tweet?text=${title}&url=${url}`, '_blank');
        this.showMobileShare = false;
    }

    // ── Navigation ────────────────────────────────────────────────────────
    handleBack() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: '/blogs' }
        });
    }

    handleRelatedClick(event) {
        const slug = event.currentTarget.dataset.slug;
        if (!slug) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: `/blogs/blog?slug=${encodeURIComponent(slug)}` }
        });
    }

    // ── Computed getters ──────────────────────────────────────────────────
    get hasTags() {
        return this.tags && this.tags.length > 0;
    }

    get hasRelatedBlogs() {
        return this.relatedBlogs && this.relatedBlogs.length > 0;
    }

    get mobileShareChevronClass() {
        return `share-chevron ${this.showMobileShare ? 'share-chevron--open' : ''}`;
    }
}