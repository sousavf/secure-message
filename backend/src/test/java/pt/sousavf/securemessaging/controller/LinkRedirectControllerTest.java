package pt.sousavf.securemessaging.controller;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
public class LinkRedirectControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    public void testDirectLinkShowsBrowserRedirectPage() throws Exception {
        // Test with a valid UUID format
        String messageId = "123e4567-e89b-12d3-a456-426614174000";
        
        mockMvc.perform(get("/" + messageId)
                .header("User-Agent", "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)")
                .header("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"))
                .andExpect(status().isOk())
                .andExpect(view().name("browser-redirect"))
                .andExpect(model().attribute("messageId", messageId))
                .andExpect(model().attribute("linkType", "direct"))
                .andExpect(model().attribute("isIOS", true));
    }

    @Test
    public void testPreviewLinkShowsBrowserRedirectPage() throws Exception {
        // Test with a valid UUID format
        String messageId = "123e4567-e89b-12d3-a456-426614174000";
        
        mockMvc.perform(get("/" + messageId + "/preview")
                .header("User-Agent", "Mozilla/5.0 (Linux; Android 13)")
                .header("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"))
                .andExpect(status().isOk())
                .andExpect(view().name("browser-redirect"))
                .andExpect(model().attribute("messageId", messageId))
                .andExpect(model().attribute("linkType", "preview"))
                .andExpect(model().attribute("isAndroid", true));
    }

    @Test
    public void testInvalidUUIDReturns404() throws Exception {
        // Test with an invalid UUID format
        mockMvc.perform(get("/invalid-uuid")
                .header("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"))
                .andExpect(status().isOk())
                .andExpect(view().name("error/404"));
    }

    @Test
    public void testDesktopBrowserDetection() throws Exception {
        String messageId = "123e4567-e89b-12d3-a456-426614174000";
        
        mockMvc.perform(get("/" + messageId)
                .header("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
                .header("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"))
                .andExpect(status().isOk())
                .andExpect(view().name("browser-redirect"))
                .andExpect(model().attribute("isIOS", false))
                .andExpect(model().attribute("isAndroid", false));
    }
}