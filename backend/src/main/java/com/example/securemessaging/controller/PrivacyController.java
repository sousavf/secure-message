package com.example.securemessaging.controller;

import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

@Controller
@RequestMapping("/privacy")
public class PrivacyController {

    @GetMapping
    public String privacyPolicy(Model model) {
        model.addAttribute("lastUpdated", LocalDateTime.now().format(DateTimeFormatter.ofPattern("MMMM dd, yyyy")));
        model.addAttribute("appName", "Safe Whisper");
        return "privacy-policy";
    }
    
    @GetMapping("/policy")
    public String privacyPolicyAlias(Model model) {
        return privacyPolicy(model);
    }
}