public with sharing class PortfolioVisitorEmailNotifications implements Queueable, Database.AllowsCallouts {
    
    private Id leadId;
    private static final String SELF_EMAIL_TEMPLATE_ID = '00XgK00000DGSs5UAH';
    //private static final String SELF_EMAIL_TEMPLATE_ID = '00XgK00000DUvPbUAL';
    private static final String PORTFOLIO_VISITOR_EMAIL_TEMPLATE_ID = '00XgK00000DFpE4UAL';
    //private static final String PORTFOLIO_VISITOR_EMAIL_TEMPLATE_ID = '00XgK00000DUnVLUA1';
    private static final String ORG_WIDE_EMAIL_ID = '0D2gK0000001gGXSAY';
    public PortfolioVisitorEmailNotifications(Id leadId) {
        this.leadId = leadId;
    }

    public void execute(QueueableContext qc) {
        Lead ld = [SELECT Id, FirstName, LastName, Email, Subject__c, Description FROM Lead WHERE Id = :leadId];

        // 1️⃣ Email template: Send email to YOU (admin)
        Messaging.SingleEmailMessage adminMail = new Messaging.SingleEmailMessage();
        adminMail.setTemplateId(SELF_EMAIL_TEMPLATE_ID);
        adminMail.setTargetObjectId(ld.Id);
        adminMail.setToAddresses(new String[] { 'gssolanki30@gmail.com' });
        adminMail.setSaveAsActivity(false);
        adminMail.setOrgWideEmailAddressId(ORG_WIDE_EMAIL_ID);

        // 2️⃣ Email template: Confirmation email to Visitor
        Messaging.SingleEmailMessage visitorMail = new Messaging.SingleEmailMessage();
        visitorMail.setTemplateId(PORTFOLIO_VISITOR_EMAIL_TEMPLATE_ID);
        visitorMail.setTargetObjectId(ld.Id);
        visitorMail.setSaveAsActivity(false);
        visitorMail.setOrgWideEmailAddressId(ORG_WIDE_EMAIL_ID);
        visitorMail.setToAddresses(new String[] { ld.Email });

        // Send both emails
        Messaging.sendEmail(new Messaging.Email[] { adminMail, visitorMail });
    }
}