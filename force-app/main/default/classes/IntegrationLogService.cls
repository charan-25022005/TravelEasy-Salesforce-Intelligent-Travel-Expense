/**
 * @description Enterprise logging service for asynchronous executions, external API dispatches,
 * and background reconciliation results. Ensures logs are persisted safely without rolling back.
 */
public with sharing class IntegrationLogService {

    /**
     * @description Inserts an integration log record.
     * @param serviceName Name of the initiating service
     * @param endpoint Target URL / destination
     * @param requestPayload Request JSON or message
     * @param responsePayload Response JSON or payload
     * @param statusCode HTTP / processing status code
     * @param status 'Success', 'Failure', 'Pending'
     * @param errorMessage Detailed diagnostic error message
     * @param relatedId Associated record Id (e.g. Reimbursement Id)
     */
    public static void log(
        String serviceName,
        String endpoint,
        String requestPayload,
        String responsePayload,
        Integer statusCode,
        String status,
        String errorMessage,
        String relatedId
    ) {
        try {
            Integration_Log__c entry = new Integration_Log__c(
                Service_Name__c = serviceName,
                Endpoint__c = endpoint,
                Request_Payload__c = requestPayload,
                Response_Payload__c = responsePayload,
                Status_Code__c = statusCode,
                Status__c = status,
                Error_Message__c = errorMessage,
                Related_Record_Id__c = relatedId
            );
            if (Schema.sObjectType.Integration_Log__c.isCreateable()) {
                Database.insert(entry, false);
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'IntegrationLogService failed to insert log: ' + ex.getMessage());
        }
    }
}
