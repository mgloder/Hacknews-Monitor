import Foundation

struct HNStory: Codable, Identifiable {
    let id: Int
    let title: String
    let url: String?
    let score: Int
    let time: TimeInterval
    
    var timestamp: Date {
        return Date(timeIntervalSince1970: time)
    }
}

class HNService {
    private var keywords: Set<String> = []
    private var topics: Set<String> = []
    
    init() {
        // Load saved filters
        loadSavedFilters()
    }
    
    private func loadSavedFilters() {
        let defaults = UserDefaults.standard
        if let savedKeywords = defaults.array(forKey: "savedKeywords") as? [String] {
            self.keywords = Set(savedKeywords)
        }
        if let savedTopics = defaults.array(forKey: "savedTopics") as? [String] {
            self.topics = Set(savedTopics)
        }
        print("Loaded filters - Keywords: \(keywords), Topics: \(topics)")
    }
    
    func setFilters(keywords: Set<String>, topics: Set<String>) {
        self.keywords = keywords
        self.topics = topics
        
        // Save filters
        let defaults = UserDefaults.standard
        defaults.set(Array(keywords), forKey: "savedKeywords")
        defaults.set(Array(topics), forKey: "savedTopics")
        defaults.synchronize()
        
        print("Saved filters - Keywords: \(keywords), Topics: \(topics)")
    }
    
    func fetchTopStories() async throws -> [HNStory] {
        // Fetch top story IDs
        let topStoriesURL = URL(string: "https://hacker-news.firebaseio.com/v0/topstories.json")!
        let (data, _) = try await URLSession.shared.data(from: topStoriesURL)
        let storyIds = try JSONDecoder().decode([Int].self, from: data)
        
        // Fetch first 100 stories
        let stories = try await withThrowingTaskGroup(of: HNStory?.self) { group in
            var stories: [HNStory] = []
            
            for id in storyIds.prefix(100) {
                group.addTask {
                    try await self.fetchStory(id: id)
                }
            }
            
            for try await story in group {
                if let story = story {
                    stories.append(story)
                }
            }
            
            return stories.sorted { $0.score > $1.score }
        }
        
        return filterStories(stories)
    }
    
    private func fetchStory(id: Int) async throws -> HNStory? {
        let storyURL = URL(string: "https://hacker-news.firebaseio.com/v0/item/\(id).json")!
        let (data, _) = try await URLSession.shared.data(from: storyURL)
        return try JSONDecoder().decode(HNStory.self, from: data)
    }
    
    private func filterStories(_ stories: [HNStory]) -> [HNStory] {
        guard !keywords.isEmpty || !topics.isEmpty else { 
            print("No filters applied, returning all stories")
            return stories 
        }
        
        let filteredStories = stories.filter { story in
            // Only include stories that match at least one keyword or topic
            if !keywords.isEmpty {
                let matchesKeyword = keywords.contains { keyword in
                    story.title.lowercased().contains(keyword.lowercased())
                }
                if !matchesKeyword {
                    return false
                }
            }
            
            if !topics.isEmpty {
                let matchesTopic = topics.contains { topic in
                    story.title.lowercased().contains(topic.lowercased())
                }
                if !matchesTopic {
                    return false
                }
            }
            
            return true
        }
        
        print("Filtering results:")
        print("- Original stories count: \(stories.count)")
        print("- Filtered stories count: \(filteredStories.count)")
        print("- Applied keywords: \(keywords)")
        print("- Applied topics: \(topics)")
        
        // Print first few filtered stories for debugging
        filteredStories.prefix(5).forEach { story in
            print("- Matched story: \(story.title)")
        }
        
        return filteredStories
    }
} 