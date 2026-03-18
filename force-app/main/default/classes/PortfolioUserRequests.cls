public with sharing class PortfolioUserRequests {

    private static final String GOVIND_ID = 'a00gK00000WZWU1QAP';
    
    @AuraEnabled(cacheable=false)
    public static String createPortfolioLead(String firstName, String lastName, String userEmail, String subject, String description) {
        try {
            Lead ld = new Lead();
            ld.FirstName = firstName;
            ld.LastName = lastName;
            ld.LeadSource = 'Web';
            ld.Email = userEmail;
            ld.Subject__c = subject;
            ld.Description = description;
            ld.Company = 'Portfolio Visitor';
            insert ld;

            PortfolioVisitorEmailNotifications.sendVisitorEmails(ld.Id);

            return 'Success';
        } catch (Exception e) {
            System.debug('ERROR in createPortfolioLead => ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> fetchPortfolioSkills() {
        try{
            Map<String, Skill_UI_Config__mdt> uiConfigMap = new Map<String, Skill_UI_Config__mdt>();
            for (Skill_UI_Config__mdt cfg : [
                SELECT Id, Label, Icon__c, Gradient_Class__c, Skill_Name__c FROM Skill_UI_Config__mdt
            ]) {
                uiConfigMap.put(cfg.Skill_Name__c, cfg);
            }

            List<Map<String, Object>> response = new List<Map<String, Object>>();

            for (Skill__c s : [SELECT Id, Name, Personal_Info__c, TechStack__c FROM Skill__c WHERE
                        Personal_Info__c =: GOVIND_ID]) {
                Map<String, Object> item = new Map<String, Object>();
                item.put('category', s.Name);
                item.put('skills', s.TechStack__c != null ? s.TechStack__c.split(';') : new List<String>());

                Skill_UI_Config__mdt cfg = uiConfigMap.get(s.Name);
                item.put('icon', cfg != null ? cfg.Icon__c : 'utility:apps');
                item.put('gradientClass', cfg != null ? cfg.Gradient_Class__c : 'gradient-default');

                response.add(item);
            }

            return response;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> fetchPortfolioExperiences() {
        try{
            List<Map<String, Object>> result = new List<Map<String, Object>>();

            List<Experience__c> expList = [
                SELECT Id, Designation__c, Company__c,
                    From__c, To__c, Location__c, Type__c,
                    Experience_1__c, Experience_2__c, Experience_3__c,
                    Experience_4__c, Experience_5__c,
                    Tech_Stack__c
                FROM Experience__c
                ORDER BY From__c DESC
            ];

            for (Experience__c exp : expList) {
                Map<String, Object> expMap = new Map<String, Object>();

                expMap.put('title', exp.Designation__c);
                expMap.put('company', exp.Company__c);

                // Period (TEXT → TEXT)
                String period;
                if (String.isBlank(exp.To__c)) {
                    period = exp.From__c + ' - Present';
                } else {
                    period = exp.From__c + ' - ' + exp.To__c;
                }
                expMap.put('period', period);

                expMap.put('location', exp.Location__c);
                expMap.put('type', exp.Type__c);

                // Achievements
                List<String> achievements = new List<String>();
                if (!String.isBlank(exp.Experience_1__c)) achievements.add(exp.Experience_1__c);
                if (!String.isBlank(exp.Experience_2__c)) achievements.add(exp.Experience_2__c);
                if (!String.isBlank(exp.Experience_3__c)) achievements.add(exp.Experience_3__c);
                if (!String.isBlank(exp.Experience_4__c)) achievements.add(exp.Experience_4__c);
                if (!String.isBlank(exp.Experience_5__c)) achievements.add(exp.Experience_5__c);
                expMap.put('achievements', achievements);

                // Technologies (multi-select picklist)
                List<String> technologies = String.isBlank(exp.Tech_Stack__c)
                    ? new List<String>()
                    : exp.Tech_Stack__c.split(';');
                expMap.put('technologies', technologies);

                result.add(expMap);
            }

            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}