package pt.sousavf.securemessaging.controller;

import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestHeader;

import java.util.UUID;

/**
 * Controller for handling Universal Links when accessed via web browser
 * When users open Safe Whisper links in a browser instead of the app,
 * this shows a friendly message encouraging them to use the mobile app
 */
@Controller
public class LinkRedirectController {

    /**
     * Handle direct whisper links: /{messageId}
     * Shows a friendly error page when accessed in browser
     * Only handles requests that accept HTML (browsers), not API requests
     */
    @GetMapping(value = "/{messageId}", produces = "text/html")
    public String handleDirectLink(@PathVariable String messageId, 
                                   @RequestHeader(value = "User-Agent", required = false) String userAgent,
                                   Model model) {
        
        // Validate that messageId is a valid UUID format
        try {
            UUID.fromString(messageId);
        } catch (IllegalArgumentException e) {
            // If not a valid UUID, let Spring handle it normally (404)
            return "error/404";
        }
        
        // Add model attributes for the error page
        model.addAttribute("messageId", messageId);
        model.addAttribute("linkType", "direct");
        model.addAttribute("isIOS", isIOSUserAgent(userAgent));
        model.addAttribute("isAndroid", isAndroidUserAgent(userAgent));
        
        return "browser-redirect";
    }
    
    /**
     * Handle preview whisper links: /{messageId}/preview
     * Shows a friendly error page when accessed in browser
     * Only handles requests that accept HTML (browsers), not API requests
     */
    @GetMapping(value = "/{messageId}/preview", produces = "text/html")
    public String handlePreviewLink(@PathVariable String messageId,
                                    @RequestHeader(value = "User-Agent", required = false) String userAgent,
                                    Model model) {
        
        // Validate that messageId is a valid UUID format
        try {
            UUID.fromString(messageId);
        } catch (IllegalArgumentException e) {
            // If not a valid UUID, let Spring handle it normally (404)
            return "error/404";
        }
        
        // Add model attributes for the error page
        model.addAttribute("messageId", messageId);
        model.addAttribute("linkType", "preview");
        model.addAttribute("isIOS", isIOSUserAgent(userAgent));
        model.addAttribute("isAndroid", isAndroidUserAgent(userAgent));
        
        return "browser-redirect";
    }
    
    /**
     * Check if the user agent indicates an iOS device
     */
    private boolean isIOSUserAgent(String userAgent) {
        if (userAgent == null) return false;
        return userAgent.toLowerCase().contains("iphone") || 
               userAgent.toLowerCase().contains("ipad") ||
               userAgent.toLowerCase().contains("ipod");
    }
    
    /**
     * Check if the user agent indicates an Android device
     */
    private boolean isAndroidUserAgent(String userAgent) {
        if (userAgent == null) return false;
        return userAgent.toLowerCase().contains("android");
    }
}