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
    
    func setFilters(keywords: Set<String>, topics: Set<String>) {
        self.keywords = keywords
        self.topics = topics
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
        guard !keywords.isEmpty || !topics.isEmpty else { return stories }
        
        return stories.filter { story in
            let matchesKeyword = keywords.isEmpty || keywords.contains { keyword in
                story.title.lowercased().contains(keyword.lowercased())
            }
            
            let matchesTopic = topics.isEmpty || topics.contains { topic in
                story.title.lowercased().contains(topic.lowercased())
            }
            
            return matchesKeyword || matchesTopic
        }
    }
} 