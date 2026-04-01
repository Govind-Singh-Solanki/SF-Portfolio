import { api, LightningElement, wire } from 'lwc';
import { getRecord } from "lightning/uiRecordApi";
import LETS_CONNECT from "@salesforce/label/c.Lets_Connect_Button";
import VIEW_RESUME from "@salesforce/label/c.Resume_Button";
import PROFILE_BADGE from "@salesforce/label/c.Profile_Badge";
import PORTFOLIO_HEADER from "@salesforce/label/c.Portfolio_Header";
import PORTFOLIO_SUB_HEADER from "@salesforce/label/c.Portfolio_Sub_Header";
import PORTFOLIO_HERO_SUBTITLE from "@salesforce/label/c.Portfolio_Hero_Subtitle";
import PORTFOLIO_HERO_SUBTITLE2 from "@salesforce/label/c.Portfolio_Hero_Subtitle_2";
import { publish, subscribe,MessageContext } from 'lightning/messageService';
import SECTION_NAVIGATION from "@salesforce/messageChannel/SectionNavigationChannel__c";
import PORTFOLIO_ASSETS from '@salesforce/resourceUrl/Portfolio_Assets';
import LINKEDIN from '@salesforce/resourceUrl/LinkedIn';
import GITHUB from '@salesforce/resourceUrl/Github';
import { loadStyle, loadScript } from 'lightning/platformResourceLoader';

export default class Hero extends LightningElement {

    subtitle1 = '';
    subtitle2 = '';
    letsConnect = LETS_CONNECT;
    viewResume = VIEW_RESUME;
    profileBadge = PROFILE_BADGE;
    portfolioHeader = PORTFOLIO_HEADER;
    portfolioSubHeader = PORTFOLIO_SUB_HEADER;
    portfolioSubtitle = PORTFOLIO_HERO_SUBTITLE;
    portfolioSubtitle2 = PORTFOLIO_HERO_SUBTITLE2;
    @api portfolioBadge;

    @wire(MessageContext)
    messageContext;

    subscription = null;

    connectedCallback() {
        if(!this.subscription) {
            this.subscription = subscribe(
                this.messageContext,
                SECTION_NAVIGATION,
                (payload) => this.handleNavigation(payload)
            );
        }
    }

    @wire(getRecord, { recordId: "a00gK00000WZWU1QAP", layoutTypes: ["Full"] })
    personalInfo({ error, data }) {
        if (error) {
            this.subtitle1 = "Experienced Salesforce Developer specializing in Lightning Web Components, Apex development, and cutting-edge Agentforce solutions.";
            this.subtitle2 = "2+ years of building scalable, user-centric solutions across the Salesforce ecosystem.";
        } else if (data) {
            // console.log('Info Details -> ', data);
            this.subtitle1 = data.fields.Subtitle_1__c.value;
            this.subtitle2 = data.fields.Subtitle_2__c.value;
        }
    }

    handleNavigation(payload) {
        // console.log('Recieved payload --> ', payload);
        // console.log('Recieved payload section --> ', payload.clickedSection);
        if (payload.clickedSection === 'home') {
            this.template.host.scrollIntoView({ behavior: 'smooth' });
        }
    }

    // Static Resource URLs
    profilePhotoUrl = PORTFOLIO_ASSETS + '/Portfolio_Assets/Govind_Singh_Solanki.png';
    salesforceLogoUrl = PORTFOLIO_ASSETS + '/Portfolio_Assets/Salesforce_Logo.png';
    astroMascotUrl = PORTFOLIO_ASSETS + '/Portfolio_Assets/Salesforce_Logo.png';

    renderedCallback() {
        // loads third-party/external css
        loadStyle(this, LINKEDIN + '/style.css');
        loadStyle(this, GITHUB + '/style.css');
  }

    // Event handlers
    handleConnect(event) {
        const section = event.currentTarget.dataset.section;
        // console.log('Section Clicked --> ', section);
        const payload = {clickedSection : section};
        publish(this.messageContext, SECTION_NAVIGATION, payload);
    }

    handleResume() {
        window.open('https://drive.google.com/file/d/1nEbtA-zukaSHvdyfVGPgPPAulm-nbBdJ/view?usp=sharing', '_blank');
    }

    handleLinkedIn() {
        window.open('https://www.linkedin.com/in/govind-singh-solanki/', '_blank');
    }

    handleGithub() {
        window.open('https://github.com/Govind-Singh-Solanki', '_blank');
    }

}