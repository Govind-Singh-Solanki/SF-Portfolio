public with sharing class BlogLikeController {
    
    private without sharing class ElevatedReader {
        public Integer countLikes(String blogId) {
            return [
                SELECT COUNT()
                FROM Blog_Likes__c
                WHERE Blog__c = :blogId
            ];
        }

        public List<Blog_Likes__c> findLike(Id blogId) {
            return [
                SELECT Id
                FROM Blog_Likes__c
                WHERE Blog__c = :blogId
                LIMIT 1
            ];
        }
    }

    private without sharing class ElevatedWriter {
        public void insertLike(Blog_Likes__c rec) { insert rec; }
        public void deleteLike(List<Blog_Likes__c> recs) { delete recs; }
    }

    // ── GET LIKE COUNT ────────────────────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static Integer getLikeCount(String blogId) {
        if (String.isBlank(blogId)) return 0;
        return new ElevatedReader().countLikes(blogId);
    }

    // ── ADD LIKE ──────────────────────────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static void addLike(String blogId) {
        if (String.isBlank(blogId)) {
            throw new AuraHandledException('Blog ID is required.');
        }

        // Generate a session token — passed from JS localStorage
        // We just create the record; deduplication is handled in JS via localStorage
        Blog_Likes__c bl = new Blog_Likes__c(
            Blog__c         = blogId,
            Visitor_Id__c  = generateToken(blogId)
        );
        new ElevatedWriter().insertLike(bl);
    }

    // ── REMOVE LIKE ───────────────────────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static void removeLike(String blogId) {
        if (String.isBlank(blogId)) {
            throw new AuraHandledException('Blog ID is required.');
        }

        // Delete all like records for this blog created in last 24hrs
        // Since we can't match guest token from server side without passing it,
        // we delete by blogId — the JS localStorage prevents double-liking
        // List<Blog_Likes__c> likes = [
        //     SELECT Id
        //     FROM Blog_Likes__c
        //     WHERE Blog__c = :blogId
        //     ORDER BY CreatedDate DESC
        //     LIMIT 1
        // ];

        List<Blog_Likes__c> likedBlog =  new ElevatedReader().findLike(blogId);

        if (!likedBlog.isEmpty()) {
            new ElevatedWriter().deleteLike(likedBlog);
        }
    }

    private static String generateToken(String blogId) {
        String raw = blogId + String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.random());
        Blob hash  = Crypto.generateDigest('SHA-256', Blob.valueOf(raw));
        return EncodingUtil.convertToHex(hash).substring(0, 32);
    }

}