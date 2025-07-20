package pt.sousavf.securemessaging.dto;

import java.time.LocalDate;

public class StatsResponse {

    private LocalDate date;
    private long messagesCreated;
    private long messagesRead;
    private long activeMessages;
    private long totalConsumedMessages;

    public StatsResponse() {}

    public StatsResponse(LocalDate date, long messagesCreated, long messagesRead, 
                        long activeMessages, long totalConsumedMessages) {
        this.date = date;
        this.messagesCreated = messagesCreated;
        this.messagesRead = messagesRead;
        this.activeMessages = activeMessages;
        this.totalConsumedMessages = totalConsumedMessages;
    }

    public LocalDate getDate() {
        return date;
    }

    public void setDate(LocalDate date) {
        this.date = date;
    }

    public long getMessagesCreated() {
        return messagesCreated;
    }

    public void setMessagesCreated(long messagesCreated) {
        this.messagesCreated = messagesCreated;
    }

    public long getMessagesRead() {
        return messagesRead;
    }

    public void setMessagesRead(long messagesRead) {
        this.messagesRead = messagesRead;
    }

    public long getActiveMessages() {
        return activeMessages;
    }

    public void setActiveMessages(long activeMessages) {
        this.activeMessages = activeMessages;
    }

    public long getTotalConsumedMessages() {
        return totalConsumedMessages;
    }

    public void setTotalConsumedMessages(long totalConsumedMessages) {
        this.totalConsumedMessages = totalConsumedMessages;
    }
}