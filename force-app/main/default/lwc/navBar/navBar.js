import { api, LightningElement, wire } from 'lwc';
import { publish,MessageContext } from 'lightning/messageService';
import SECTION_NAVIGATION from "@salesforce/messageChannel/SectionNavigationChannel__c";
import NAV_MENU from "@salesforce/label/c.Navbar_Menu";
import BLOG_MENU from "@salesforce/label/c.Blog_Navigation";
import { NavigationMixin } from 'lightning/navigation';
import { CurrentPageReference } from 'lightning/navigation';
import PORTFOLIO_ASSETS  from '@salesforce/resourceUrl/Portfolio_Assets';

export default class NavBar extends NavigationMixin(LightningElement) {

    @wire(MessageContext)
    messageContext;

    navbarVariant = '';
    formFactor = '';

    sfLogo = PORTFOLIO_ASSETS + '/Portfolio_Assets/Portfolio_Logo.png';

    isMobileMenuOpen = false;
    activeSection = 'home';
    navItem = {
        home: '',
        skills: '',
        experience: '',
        contact: '',
        blog: '',
        resume: ''
    };

    get isHome() {
        return this.navbarVariant === 'Home';
    }

    currentPageReference;
    pageApiName;
    urlStateParameters;

    @wire(CurrentPageReference)
    setCurrentPageReference(currentPageReference) {
        this.currentPageReference = currentPageReference;
        if (currentPageReference) {
            this.navbarVariant = currentPageReference.attributes.name;
            this.formFactor = currentPageReference.state.formFactor;
            // console.log('Custom Parameter Value: ', this.navbarVariant);
            console.log('Custom Parameter Value: ', currentPageReference);
            if(this.navbarVariant === 'Home') {
            const items = NAV_MENU.split(';').map(item => item.trim());
                this.navItem = {
                    home: items[0],
                    skills: items[1],
                    experience: items[2],
                    contact: items[3],
                    blog: items[4],
                    resume: items[5]
                };
            } else {
                const items = BLOG_MENU.split(';').map(item => item.trim());
                this.navItem = {
                    home: items[0],
                    categories: items[1],
                    subscribe: items[2]
                };
            }
            // console.log('Nav Object --> ', this.navItem);
        }
    }

    connectedCallback() {
        this.setupScrollListener();
        this.isMobileMenuOpen = false;
    }

    setupScrollListener() {
        window.addEventListener('scroll', this.handleScroll.bind(this));
    }

    handleScroll() {
        const sections = ['home', 'skills', 'experience', 'contact'];
        const scrollPosition = window.scrollY + 100;

        sections.forEach(section => {
            const element = document.getElementById(section);
            if (element) {
                const offsetTop = element.offsetTop;
                const offsetHeight = element.offsetHeight;
                
                if (scrollPosition >= offsetTop && scrollPosition < offsetTop + offsetHeight) {
                    this.activeSection = section;
                }
            }
        });
    }

    get mobileNavClass() {
        return this.isMobileMenuOpen ? 'mobile-nav open' : 'mobile-nav';
    }

    toggleMobileMenu() {
        this.isMobileMenuOpen = !this.isMobileMenuOpen;
        const button = this.template.querySelector('.mobile-menu-btn');
        button.classList.toggle('open', this.isMobileMenuOpen);
    }

    navigateToSection(event) {
        // console.log('Click Event!');
        const section = event.currentTarget.dataset.section;
        // console.log('Section Clicked --> ', section);
        if(section === 'backToHome'){
            this.navigateToBlog(section)
        } else {
            const payload = {clickedSection : section};
            publish(this.messageContext, SECTION_NAVIGATION, payload);
        }
        this.closeMobileMenu();
    }

    navigateToBlog(section) {
        // const url = section === 'backToHome' ? '/' : '/blogs';
        this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: section === 'backToHome' ? '/' : '/blogs'
                }
            });
        this.closeMobileMenu();
    }

    closeMobileMenu() {
        this.isMobileMenuOpen = false;

        const button = this.template.querySelector('.mobile-menu-btn');
        if (button) {
            button.classList.remove('open');
        }
    }

    openResume() {
        window.open('https://drive.google.com/file/d/1nEbtA-zukaSHvdyfVGPgPPAulm-nbBdJ/view?usp=sharing', '_blank');
    }

}