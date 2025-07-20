package pt.sousavf.securemessaging.controller;

import pt.sousavf.securemessaging.dto.StatsResponse;
import pt.sousavf.securemessaging.service.MessageService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;

@RestController
@RequestMapping("/stats")
@CrossOrigin(origins = {"http://localhost:3000", "https://localhost:3000"})
public class StatsController {

    private static final Logger logger = LoggerFactory.getLogger(StatsController.class);

    private final MessageService messageService;

    public StatsController(MessageService messageService) {
        this.messageService = messageService;
    }

    @GetMapping
    public ResponseEntity<StatsResponse> getTodayStats() {
        try {
            logger.info("Received request for today's stats");
            StatsResponse stats = messageService.getTodayStats();
            return ResponseEntity.ok(stats);
        } catch (Exception e) {
            logger.error("Error retrieving today's stats", e);
            return ResponseEntity.internalServerError().build();
        }
    }

    @GetMapping("/{date}")
    public ResponseEntity<StatsResponse> getStatsForDate(
            @PathVariable @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        try {
            logger.info("Received request for stats on date: {}", date);
            StatsResponse stats = messageService.getDailyStats(date);
            return ResponseEntity.ok(stats);
        } catch (Exception e) {
            logger.error("Error retrieving stats for date: {}", date, e);
            return ResponseEntity.internalServerError().build();
        }
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<String> handleGeneralException(Exception e) {
        logger.error("Unexpected error in StatsController", e);
        return ResponseEntity.internalServerError()
                           .body("An unexpected error occurred while retrieving stats");
    }
}