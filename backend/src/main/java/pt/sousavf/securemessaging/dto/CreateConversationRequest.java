package pt.sousavf.securemessaging.dto;

public class CreateConversationRequest {
    private Integer ttlHours;

    public CreateConversationRequest() {}

    public CreateConversationRequest(Integer ttlHours) {
        this.ttlHours = ttlHours;
    }

    public Integer getTtlHours() {
        return ttlHours;
    }

    public void setTtlHours(Integer ttlHours) {
        this.ttlHours = ttlHours;
    }
}
