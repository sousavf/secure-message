package pt.sousavf.securemessaging.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.time.LocalDateTime;
import java.util.List;

/**
 * Response DTO for paginated message retrieval
 * Supports cursor-based pagination for efficient infinite scroll
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public class MessagePageResponse {

    private List<MessageResponse> messages;
    private boolean hasMore;
    private LocalDateTime nextCursor;
    private int pageSize;

    public MessagePageResponse() {}

    public MessagePageResponse(List<MessageResponse> messages, boolean hasMore, LocalDateTime nextCursor, int pageSize) {
        this.messages = messages;
        this.hasMore = hasMore;
        this.nextCursor = nextCursor;
        this.pageSize = pageSize;
    }

    public List<MessageResponse> getMessages() {
        return messages;
    }

    public void setMessages(List<MessageResponse> messages) {
        this.messages = messages;
    }

    public boolean isHasMore() {
        return hasMore;
    }

    public void setHasMore(boolean hasMore) {
        this.hasMore = hasMore;
    }

    public LocalDateTime getNextCursor() {
        return nextCursor;
    }

    public void setNextCursor(LocalDateTime nextCursor) {
        this.nextCursor = nextCursor;
    }

    public int getPageSize() {
        return pageSize;
    }

    public void setPageSize(int pageSize) {
        this.pageSize = pageSize;
    }
}
