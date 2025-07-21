package com.example.securemessaging.controller;

import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;

@Controller
@RequestMapping("/support")
public class SupportController {

    @GetMapping
    public String support(Model model) {
        model.addAttribute("supportEmail", "support@stratholme.eu");
        model.addAttribute("appName", "Safe Whisper");
        return "support";
    }
    
    @GetMapping("/contact")
    public String supportContact(Model model) {
        return support(model);
    }
    
    @GetMapping("/help")
    public String supportHelp(Model model) {
        return support(model);
    }
}