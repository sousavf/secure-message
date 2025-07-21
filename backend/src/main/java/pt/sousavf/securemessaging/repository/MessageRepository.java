package pt.sousavf.securemessaging.repository;

import pt.sousavf.securemessaging.entity.Message;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface MessageRepository extends JpaRepository<Message, UUID> {

    @Query("SELECT m FROM Message m WHERE m.id = :id AND m.consumed = false AND m.expiresAt > :now")
    Optional<Message> findAvailableMessage(@Param("id") UUID id, @Param("now") LocalDateTime now);

    @Modifying
    @Query("DELETE FROM Message m WHERE m.expiresAt < :now")
    int deleteExpiredMessages(@Param("now") LocalDateTime now);

    @Modifying
    @Query("DELETE FROM Message m WHERE m.consumed = true AND m.readAt < :threshold")
    int deleteConsumedMessages(@Param("threshold") LocalDateTime threshold);

    @Query("SELECT COUNT(m) FROM Message m WHERE DATE(m.createdAt) = DATE(:date)")
    long countMessagesCreatedOnDate(@Param("date") LocalDateTime date);

    @Query("SELECT COUNT(m) FROM Message m WHERE DATE(m.readAt) = DATE(:date) AND m.consumed = true")
    long countMessagesReadOnDate(@Param("date") LocalDateTime date);

    @Query("SELECT m FROM Message m WHERE m.expiresAt < :now")
    List<Message> findExpiredMessages(@Param("now") LocalDateTime now);

    @Query("SELECT COUNT(m) FROM Message m WHERE m.consumed = false AND m.expiresAt > :now")
    long countActiveMessages(@Param("now") LocalDateTime now);

    @Query("SELECT COUNT(m) FROM Message m WHERE m.consumed = true")
    long countConsumedMessages();
}