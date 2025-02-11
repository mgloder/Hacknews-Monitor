import AppKit

class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var hnService: HNService
    private var stories: [HNStory] = []
    private var timer: Timer?
    
    override init() {
        self.hnService = HNService()
        super.init()
        setupMenuBar()
        startNewsTimer()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "HN"
        
        let menu = NSMenu()
        statusItem.menu = menu
        updateMenu()
    }
    
    private func startNewsTimer() {
        // Refresh every hour
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.refreshNews()
        }
        refreshNews()
    }
    
    private func refreshNews() {
        Task {
            do {
                stories = try await hnService.fetchTopStories()
                DispatchQueue.main.async {
                    self.updateMenu()
                }
            } catch {
                print("Error fetching news: \(error)")
            }
        }
    }
    
    private func updateMenu() {
        print("Updating menu with \(stories.count) stories")
        guard let menu = statusItem.menu else { return }
        menu.removeAllItems()
        
        // Add filter configuration
        let filterItem = NSMenuItem(title: "Configure Filters", action: #selector(showFilterConfig), keyEquivalent: "f")
        filterItem.target = self
        menu.addItem(filterItem)
        
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshClicked), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        menu.addItem(NSMenuItem.separator())
        
        // Add news items
        for story in stories {
            let title = "\(story.title) (\(story.score))"
            let item = NSMenuItem(title: title, action: #selector(openStory(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = story.url
            menu.addItem(item)
        }
        
        print("Menu updated with \(stories.count) items")
    }
    
    @objc private func openStory(_ sender: NSMenuItem) {
        guard let urlString = sender.representedObject as? String,
              let url = URL(string: urlString) else { return }
        
        NSWorkspace.shared.open([url],
                              withAppBundleIdentifier: "com.google.Chrome",
                              options: [],
                              additionalEventParamDescriptor: nil,
                              launchIdentifiers: nil)
    }
    
    @objc private func refreshClicked() {
        refreshNews()
    }
    
    @objc private func showFilterConfig() {
        let alert = NSAlert()
        alert.messageText = "Configure Filters"
        alert.informativeText = "Enter keywords and topics separated by commas"
        
        let stackView = NSStackView(frame: NSRect(x: 0, y: 0, width: 300, height: 60))
        stackView.orientation = .vertical
        stackView.spacing = 8
        
        let keywordsField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        keywordsField.placeholderString = "Keywords (e.g., AI, Python, Rust)"
        let existingKeywords = UserDefaults.standard.array(forKey: "savedKeywords") as? [String]
        keywordsField.stringValue = existingKeywords?.joined(separator: ", ") ?? ""
        
        let topicsField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        topicsField.placeholderString = "Topics (e.g., Programming, Science)"
        let existingTopics = UserDefaults.standard.array(forKey: "savedTopics") as? [String]
        topicsField.stringValue = existingTopics?.joined(separator: ", ") ?? ""
        
        stackView.addArrangedSubview(keywordsField)
        stackView.addArrangedSubview(topicsField)
        
        alert.accessoryView = stackView
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            let keywords = Set(keywordsField.stringValue.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
            let topics = Set(topicsField.stringValue.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
            
            print("Applying new filters - Keywords: \(keywords), Topics: \(topics)")
            hnService.setFilters(keywords: keywords, topics: topics)
            
            // Force a complete refresh of stories
            Task {
                do {
                    print("Fetching fresh stories with new filters...")
                    stories = try await hnService.fetchTopStories()
                    DispatchQueue.main.async { [weak self] in
                        print("Updating menu with filtered stories...")
                        self?.updateMenu()
                    }
                } catch {
                    print("Error refreshing stories: \(error)")
                }
            }
        }
    }
} 