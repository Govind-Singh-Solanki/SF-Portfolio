public with sharing class PortfolioBlogs {

    public class BlogDto {
        @AuraEnabled public Id id;
        @AuraEnabled public String title;
        @AuraEnabled public String slug;
        @AuraEnabled public String excerpt;
        @AuraEnabled public String coverImageUrl;
        @AuraEnabled public String publishedBy;
        @AuraEnabled public Date publishedDate;
        @AuraEnabled public String category;
        // add other presentation fields as needed
    }

    public class IndividualBlogData {
        @AuraEnabled public Id id;
        @AuraEnabled public String title;
        @AuraEnabled public String slug;
        @AuraEnabled public String excerpt;
        @AuraEnabled public String coverImageUrl;
        @AuraEnabled public String bannerImageUrl;
        @AuraEnabled public String publishedBy;
        @AuraEnabled public Date publishedDate;
        @AuraEnabled public String content;
        @AuraEnabled public Decimal readingTime;
        @AuraEnabled public String authorBio;
        @AuraEnabled public String tags;
        @AuraEnabled public String category;
        // add other presentation fields as needed
    }
    
    // Fetch All Blogs for Display
    @AuraEnabled(cacheable=true)
    public static List<BlogDto> fetchPublishedBlogs() {

        List<Blog__c> blogs = [
            SELECT Id, Title__c, Slug__c, Excerpt__c, Category__c, Published_Date__c, Published_By__c, CMS_Key__c, Cover_Image__c, Status__c
            FROM Blog__c
            WHERE Status__c = 'Published'
            WITH SECURITY_ENFORCED
            ORDER BY Published_Date__c DESC
        ];

        if (blogs.isEmpty()) return new List<BlogDto>();

        String deliveryBase = '/sfsites/c/cms/delivery/media/';
        List<BlogDto> out = new List<BlogDto>();

        for (Blog__c b : blogs) {
            BlogDto dto = new BlogDto();
            dto.id = b.Id;
            dto.title = b.Title__c;
            dto.slug = b.Slug__c;
            dto.excerpt = b.Excerpt__c;
            dto.publishedBy = b.Published_By__c;
            dto.publishedDate = b.Published_Date__c;
            dto.category = b.Category__c;

            // If CMS_Key__c is present, build the public LWR guest URL
            if (String.isNotBlank(b.CMS_Key__c)) {
                dto.coverImageUrl = deliveryBase + b.CMS_Key__c.trim();
            } else {
                dto.coverImageUrl = null; // or set a default placeholder path here
            }

            out.add(dto);
        }
        return out;
    }

    // Fetch Clicked Blog
    @AuraEnabled(cacheable=true)
    public static List<IndividualBlogData> fetchBlogBySlug(String slug) {
        // return [
        //     SELECT Id, Title__c, Slug__c, Excerpt__c, Content__c, Published_Date__c, Reading_Time__c, CMS_Key__c
        //     FROM Blog__c
        //     WHERE Slug__c = :slug
        //     LIMIT 1
        // ];

        List<Blog__c> blogs = [
            SELECT Id, Title__c, Slug__c, Excerpt__c, Content__c, Published_Date__c, Reading_Time__c, Published_By__c, CMS_Key__c, Banner_CMS_Key__c, Cover_Image__c, CreatedBy.Name, Author_Bio__c, Tags__c, Category__c
            FROM Blog__c
            WHERE Slug__c = :slug
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        if (blogs.isEmpty()) return new List<IndividualBlogData>();

        String deliveryBase = '/sfsites/c/cms/delivery/media/';
        List<IndividualBlogData> out = new List<IndividualBlogData>();

        for (Blog__c b : blogs) {
            IndividualBlogData dto = new IndividualBlogData();
            dto.id = b.Id;
            dto.title = b.Title__c;
            dto.slug = b.Slug__c;
            dto.excerpt = b.Excerpt__c;
            dto.publishedBy = b.Published_By__c;
            dto.publishedDate = b.Published_Date__c;
            dto.content = b.Content__c;
            dto.readingTime = b.Reading_Time__c;
            dto.authorBio = b.Author_Bio__c;
            dto.tags = b.Tags__c;
            dto.category = b.Category__c;

            // If CMS_Key__c is present, build the public LWR guest URL
            if (String.isNotBlank(b.CMS_Key__c)) {
                dto.coverImageUrl = deliveryBase + b.CMS_Key__c.trim();
                dto.bannerImageUrl = deliveryBase + b.Banner_CMS_Key__c.trim();
            } else {
                dto.coverImageUrl = null; // or set a default placeholder path here
                dto.bannerImageUrl = null; // or set a default placeholder path here
            }

            out.add(dto);
        }
        return out;
    }

    // Get Blog Like Count
    @AuraEnabled(cacheable=true)
    public static Integer getLikeCount(Id blogId) {
        return [
            SELECT COUNT()
            FROM Blog_Likes__c
            WHERE Blog__c = :blogId
        ];
    }

    // Like/Unlike Blog
    @AuraEnabled
    public static Integer toggleLike(Id blogId, String visitorId) {

        List<Blog_Likes__c> existing = [
            SELECT Id FROM Blog_Likes__c
            WHERE Blog__c = :blogId AND Visitor_Id__c = :visitorId
            LIMIT 1
        ];

        if (!existing.isEmpty()) {
            delete existing;
        } else {
            insert new Blog_Likes__c(
                Blog__c = blogId,
                Visitor_Id__c = visitorId
            );
        }

        return getLikeCount(blogId);
    }

}