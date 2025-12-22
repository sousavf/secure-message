package pt.sousavf.securemessaging.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.nio.file.*;
import java.time.LocalDateTime;
import java.util.UUID;
import java.util.Base64;

@Service
public class FileStorageService {

    private static final Logger logger = LoggerFactory.getLogger(FileStorageService.class);

    @Value("${app.file-storage.base-path:./file-storage}")
    private String baseStoragePath;

    /**
     * Store encrypted file to local filesystem
     * Files are organized by date: /file-storage/YYYY-MM-DD/uuid.enc
     */
    public String storeFile(String encryptedContent, UUID fileId, LocalDateTime expiresAt) throws IOException {
        try {
            // Create directory structure: base-path/YYYY-MM-DD/
            LocalDateTime now = LocalDateTime.now();
            String dateFolder = String.format("%04d-%02d-%02d",
                now.getYear(), now.getMonthValue(), now.getDayOfMonth());

            Path directoryPath = Paths.get(baseStoragePath, dateFolder);
            Files.createDirectories(directoryPath);

            // File path: /file-storage/YYYY-MM-DD/{uuid}.enc
            String fileName = fileId.toString() + ".enc";
            Path filePath = directoryPath.resolve(fileName);

            // Decode base64 and write binary data
            byte[] fileData = Base64.getDecoder().decode(encryptedContent);
            Files.write(filePath, fileData, StandardOpenOption.CREATE);

            logger.info("Stored file: {}, size: {} bytes, expires: {}", filePath, fileData.length, expiresAt);

            // Return relative path from base storage
            return dateFolder + "/" + fileName;
        } catch (IOException e) {
            logger.error("Failed to store file: {}", fileId, e);
            throw e;
        }
    }

    /**
     * Read encrypted file from local filesystem
     */
    public byte[] readFile(String relativePath) throws IOException {
        try {
            Path filePath = Paths.get(baseStoragePath, relativePath);

            if (!Files.exists(filePath)) {
                throw new IOException("File not found: " + relativePath);
            }

            return Files.readAllBytes(filePath);
        } catch (IOException e) {
            logger.error("Failed to read file: {}", relativePath, e);
            throw e;
        }
    }

    /**
     * Delete file from local filesystem
     */
    public boolean deleteFile(String relativePath) {
        try {
            Path filePath = Paths.get(baseStoragePath, relativePath);
            boolean deleted = Files.deleteIfExists(filePath);

            if (deleted) {
                logger.debug("Deleted file: {}", relativePath);
            }

            return deleted;
        } catch (IOException e) {
            logger.error("Failed to delete file: {}", relativePath, e);
            return false;
        }
    }

    /**
     * Delete all files in a directory (for cleanup job)
     */
    public int deleteExpiredFiles(LocalDateTime beforeDate) {
        int deletedCount = 0;

        try {
            Path basePath = Paths.get(baseStoragePath);
            if (!Files.exists(basePath)) {
                return 0;
            }

            // Iterate through date folders
            try (DirectoryStream<Path> stream = Files.newDirectoryStream(basePath)) {
                for (Path dateFolder : stream) {
                    if (!Files.isDirectory(dateFolder)) {
                        continue;
                    }

                    String folderName = dateFolder.getFileName().toString();
                    LocalDateTime folderDate = parseDateFolder(folderName);

                    // Delete entire folder if it's before the expiry date
                    if (folderDate != null && folderDate.isBefore(beforeDate)) {
                        deletedCount += deleteDirectory(dateFolder);
                    }
                }
            }

            logger.info("Deleted {} expired files older than {}", deletedCount, beforeDate);
        } catch (IOException e) {
            logger.error("Error during file cleanup", e);
        }

        return deletedCount;
    }

    /**
     * Parse date from folder name (YYYY-MM-DD)
     */
    private LocalDateTime parseDateFolder(String folderName) {
        try {
            String[] parts = folderName.split("-");
            if (parts.length == 3) {
                int year = Integer.parseInt(parts[0]);
                int month = Integer.parseInt(parts[1]);
                int day = Integer.parseInt(parts[2]);
                return LocalDateTime.of(year, month, day, 0, 0);
            }
        } catch (Exception e) {
            // Invalid folder name, ignore
        }
        return null;
    }

    /**
     * Recursively delete directory and all files
     */
    private int deleteDirectory(Path directory) throws IOException {
        int count = 0;

        try (DirectoryStream<Path> stream = Files.newDirectoryStream(directory)) {
            for (Path entry : stream) {
                if (Files.isDirectory(entry)) {
                    count += deleteDirectory(entry);
                } else {
                    Files.delete(entry);
                    count++;
                }
            }
        }

        Files.delete(directory);
        return count;
    }

    /**
     * Get storage statistics
     */
    public StorageStats getStorageStats() {
        try {
            Path basePath = Paths.get(baseStoragePath);
            if (!Files.exists(basePath)) {
                return new StorageStats(0, 0);
            }

            long totalFiles = 0;
            long totalSize = 0;

            try (DirectoryStream<Path> stream = Files.newDirectoryStream(basePath)) {
                for (Path dateFolder : stream) {
                    if (!Files.isDirectory(dateFolder)) {
                        continue;
                    }

                    try (DirectoryStream<Path> fileStream = Files.newDirectoryStream(dateFolder)) {
                        for (Path file : fileStream) {
                            if (Files.isRegularFile(file)) {
                                totalFiles++;
                                totalSize += Files.size(file);
                            }
                        }
                    }
                }
            }

            return new StorageStats(totalFiles, totalSize);
        } catch (IOException e) {
            logger.error("Error getting storage stats", e);
            return new StorageStats(0, 0);
        }
    }

    public static class StorageStats {
        private final long fileCount;
        private final long totalSizeBytes;

        public StorageStats(long fileCount, long totalSizeBytes) {
            this.fileCount = fileCount;
            this.totalSizeBytes = totalSizeBytes;
        }

        public long getFileCount() {
            return fileCount;
        }

        public long getTotalSizeBytes() {
            return totalSizeBytes;
        }

        public double getTotalSizeMB() {
            return totalSizeBytes / (1024.0 * 1024.0);
        }
    }
}
