import Foundation

public enum PlainNewsPresetSources {
    public static var sources: [PlainNewsSource] {
        PlainNewsSource.sortedByDisplayName(curatedSources)
    }

    public static let retiredSourceURLStrings: Set<String> = Set([
        "https://about.gitlab.com/atom.xml",
        "https://arize.com/feed/",
        "https://blog.ovhcloud.com/feed/",
        "https://clickhouse.com/rss.xml",
        "https://huggingface.co/blog/feed.xml",
        "https://www.confluent.io/rss.xml",
        "https://www.databricks.com/feed",
        "https://www.datadoghq.com/blog/index.xml",
        "https://www.fastly.com/blog_rss.xml",
        "https://www.getdbt.com/blog/rss.xml",
        "https://www.hashicorp.com/blog/feed.xml",
        "https://www.langchain.com/blog/rss.xml",
        "https://www.mongodb.com/company/blog/rss",
        "https://www.snowflake.com/feed/"
    ].map { PlainNewsArticle.normalizedURLString(URL(string: $0)!) })

    private static let curatedSources: [PlainNewsSource] = [
        PlainNewsSource(
            id: UUID(uuidString: "C20BC8A1-4F93-48BA-9B1E-9C494E52A5F5")!,
            name: "BBC Top Stories",
            url: URL(string: "https://feeds.bbci.co.uk/news/rss.xml")!,
            kind: .rss,
            categories: [.world]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "6A986E74-42C8-4B1C-ABEA-D2508A81B6F5")!,
            name: "BBC World",
            url: URL(string: "https://feeds.bbci.co.uk/news/world/rss.xml")!,
            kind: .rss,
            categories: [.world]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "9A9B0E7D-67AA-4CE0-B54A-E5B16E3B052D")!,
            name: "BBC Technology",
            url: URL(string: "https://feeds.bbci.co.uk/news/technology/rss.xml")!,
            kind: .rss,
            categories: [.technology]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "3C8CC5AB-0C18-44DA-B6A5-387D4AD6D02A")!,
            name: "BBC Science & Environment",
            url: URL(string: "https://feeds.bbci.co.uk/news/science_and_environment/rss.xml")!,
            kind: .rss,
            categories: [.science, .climate]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "DBD0851F-815F-46C7-B10D-D2BD367EB331")!,
            name: "BBC Business",
            url: URL(string: "https://feeds.bbci.co.uk/news/business/rss.xml")!,
            kind: .rss,
            categories: [.business, .world]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "AA14205C-0A74-494F-87E6-8CE6E3D4176E")!,
            name: "NPR Top Stories",
            url: URL(string: "https://feeds.npr.org/1001/rss.xml")!,
            kind: .rss,
            categories: [.world, .culture]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "7D4BE4EC-C55F-4636-AB7D-4929D0AEFD9E")!,
            name: "NPR World",
            url: URL(string: "https://feeds.npr.org/1004/rss.xml")!,
            kind: .rss,
            categories: [.world]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "74CBB164-0BAE-412A-8D62-1479F3626858")!,
            name: "NPR Technology",
            url: URL(string: "https://feeds.npr.org/1019/rss.xml")!,
            kind: .rss,
            categories: [.technology]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "0788F10C-6B45-4F96-A1E1-A5CDA745750D")!,
            name: "NPR Business",
            url: URL(string: "https://feeds.npr.org/1006/rss.xml")!,
            kind: .rss,
            categories: [.business]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "3396160E-A85F-4CEE-A542-E95D78E641B6")!,
            name: "NPR Science",
            url: URL(string: "https://feeds.npr.org/1007/rss.xml")!,
            kind: .rss,
            categories: [.science]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "28813DE5-5424-4C69-AEC7-1766D219DF40")!,
            name: "NPR Health",
            url: URL(string: "https://feeds.npr.org/1025/rss.xml")!,
            kind: .rss,
            categories: [.science]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "5BA3A386-A51F-43B7-9E6D-6C0B4D8D3352")!,
            name: "Guardian World",
            url: URL(string: "https://www.theguardian.com/world/rss")!,
            kind: .rss,
            categories: [.world]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "AF10F18B-63E9-430F-A3B3-5E896717287E")!,
            name: "Guardian Technology",
            url: URL(string: "https://www.theguardian.com/technology/rss")!,
            kind: .rss,
            categories: [.technology]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "E3D2D661-F48E-4502-A188-43EE2E5B5EB3")!,
            name: "Guardian Business",
            url: URL(string: "https://www.theguardian.com/business/rss")!,
            kind: .rss,
            categories: [.business, .world]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "DE6C9A8C-5EB0-46E2-A09A-463CC720675B")!,
            name: "Guardian Environment",
            url: URL(string: "https://www.theguardian.com/environment/rss")!,
            kind: .rss,
            categories: [.climate, .science]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "7AE8DE35-B99F-4775-9766-7F1909A2BB4C")!,
            name: "Guardian Science",
            url: URL(string: "https://www.theguardian.com/science/rss")!,
            kind: .rss,
            categories: [.science]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "B23D0898-7594-4767-A48D-F34CA6D928F0")!,
            name: "Al Jazeera",
            url: URL(string: "https://www.aljazeera.com/xml/rss/all.xml")!,
            kind: .rss,
            categories: [.world]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "AB6B1F5B-88D1-4B9F-8AA1-90973888B9AB")!,
            name: "The Verge",
            url: URL(string: "https://www.theverge.com/rss/index.xml")!,
            kind: .rss,
            categories: [.technology, .culture]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "0CDA932D-32C2-47AF-99D0-655A14B85DE0")!,
            name: "TechCrunch",
            url: URL(string: "https://techcrunch.com/feed/")!,
            kind: .rss,
            categories: [.technology, .business]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "71A7362C-42E8-4DF3-A905-28B15943D49D")!,
            name: "Ars Technica",
            url: URL(string: "https://feeds.arstechnica.com/arstechnica/index")!,
            kind: .rss,
            categories: [.technology, .science, .business]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "C13B3E04-3E4A-48D0-B3BB-EF7CD8F45DD4")!,
            name: "WIRED Top Stories",
            url: URL(string: "https://www.wired.com/feed/rss")!,
            kind: .rss,
            categories: [.technology, .science, .business, .culture, .ideas]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "84F34E96-B051-4C6E-8B30-09569F64124A")!,
            name: "WIRED AI",
            url: URL(string: "https://www.wired.com/feed/tag/ai/latest/rss")!,
            kind: .rss,
            categories: [.technology, .business, .ideas]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "B798CF10-6537-4336-AB76-20F9DF7A95F2")!,
            name: "WIRED Science",
            url: URL(string: "https://www.wired.com/feed/category/science/latest/rss")!,
            kind: .rss,
            categories: [.science, .climate]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "11947671-D4E6-454E-B0C3-178656D8D48D")!,
            name: "WIRED Security",
            url: URL(string: "https://www.wired.com/feed/category/security/latest/rss")!,
            kind: .rss,
            categories: [.security, .technology]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "C890D3D7-B8C7-4B8D-9DD1-4BE55E6810CB")!,
            name: "Quanta Magazine",
            url: URL(string: "https://www.quantamagazine.org/feed/")!,
            kind: .rss,
            categories: [.science, .ideas]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "D58024A6-3AB1-4611-AC0D-E4A7299D8F68")!,
            name: "NASA",
            url: URL(string: "https://www.nasa.gov/feed/")!,
            kind: .rss,
            categories: [.science]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "11658431-9E39-4811-B873-D9BC64F2E815")!,
            name: "EFF Updates",
            url: URL(string: "https://www.eff.org/rss/updates.xml")!,
            kind: .rss,
            categories: [.security, .technology, .ideas]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "E755E0D9-3136-472B-AE15-7B6D7767C46D")!,
            name: "Krebs on Security",
            url: URL(string: "https://krebsonsecurity.com/feed/")!,
            kind: .rss,
            categories: [.security, .technology]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "A6D6FE28-C5DF-45CD-A936-D1D70C9E5535")!,
            name: "Schneier on Security",
            url: URL(string: "https://www.schneier.com/feed/atom/")!,
            kind: .rss,
            categories: [.security, .technology, .ideas]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "8607A943-36B8-4F1E-9935-C8ED87422B58")!,
            name: "Stratechery",
            url: URL(string: "https://stratechery.com/feed/")!,
            kind: .rss,
            categories: [.business, .technology, .ideas]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "ED7CEDCA-839D-4B08-8BBC-4B6806E67C64")!,
            name: "Benedict Evans",
            url: URL(string: "https://www.ben-evans.com/benedictevans?format=rss")!,
            kind: .rss,
            categories: [.technology, .business, .ideas]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "2D19E205-4410-48D8-B195-20859E5F465E")!,
            name: "Platformer",
            url: URL(string: "https://www.platformer.news/rss/")!,
            kind: .rss,
            categories: [.technology, .business]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "30894B7A-56D7-4A6C-815D-78DE19EC3F38")!,
            name: "Simon Willison",
            url: URL(string: "https://simonwillison.net/atom/everything/")!,
            kind: .rss,
            categories: [.technology, .ideas]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "293AE8FA-C774-4D9B-8557-5458460D19B1")!,
            name: "Pluralistic",
            url: URL(string: "https://pluralistic.net/feed/")!,
            kind: .rss,
            categories: [.technology, .business, .culture, .ideas]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "2CA542B8-A537-47DE-8D3D-89BC32A5C663")!,
            name: "Destructoid",
            url: URL(string: "https://www.destructoid.com/feed/")!,
            kind: .rss,
            categories: [.gaming, .entertainment, .culture]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "709968E8-E7C6-48CB-890F-9BE2544567FF")!,
            name: "Eurogamer",
            url: URL(string: "https://www.eurogamer.net/feed")!,
            kind: .rss,
            categories: [.gaming, .entertainment, .culture]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "347E8218-85DB-408D-9B03-8D9301F57C76")!,
            name: "Game Developer",
            url: URL(string: "https://www.gamedeveloper.com/rss.xml")!,
            kind: .rss,
            categories: [.gaming, .business, .developer]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "461CCB54-0E5F-42D8-941C-4FD3EDD0BECE")!,
            name: "Game Informer",
            url: URL(string: "https://gameinformer.com/rss.xml")!,
            kind: .rss,
            categories: [.gaming, .entertainment, .culture]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "BAFE1907-0940-4F36-A8F6-EC8D52890A5C")!,
            name: "GameSpot",
            url: URL(string: "https://www.gamespot.com/feeds/news/")!,
            kind: .rss,
            categories: [.gaming, .entertainment, .culture]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "DE15D06A-589D-4133-B052-B5FC2A1839AE")!,
            name: "GamesIndustry.biz",
            url: URL(string: "https://www.gamesindustry.biz/feed")!,
            kind: .rss,
            categories: [.gaming, .business, .entertainment]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "814BD06B-D75C-41A1-A711-5ED23062D6FC")!,
            name: "GamesRadar+",
            url: URL(string: "https://www.gamesradar.com/feeds.xml")!,
            kind: .rss,
            categories: [.gaming, .entertainment, .culture]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "B801E85B-A517-45ED-B386-3C1DB88E7E1D")!,
            name: "Gematsu",
            url: URL(string: "https://www.gematsu.com/feed")!,
            kind: .rss,
            categories: [.gaming, .entertainment, .culture]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "36CF48EF-BACB-41B8-A54D-FB998584496D")!,
            name: "IGN Games",
            url: URL(string: "https://www.ign.com/rss/articles/feed?tags=games")!,
            kind: .rss,
            categories: [.gaming, .entertainment, .culture]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "4C197DEF-013A-4E14-916B-604615A31B5F")!,
            name: "Kotaku",
            url: URL(string: "https://kotaku.com/feed")!,
            kind: .rss,
            categories: [.gaming, .entertainment, .culture]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "208DA802-4AAA-4B4F-99B4-5E567DD8BE54")!,
            name: "Nintendo Life",
            url: URL(string: "https://www.nintendolife.com/feeds/latest")!,
            kind: .rss,
            categories: [.gaming, .entertainment, .culture]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "1B3A70D5-3612-4003-A9B2-EFB063B5D91C")!,
            name: "PC Gamer",
            url: URL(string: "https://www.pcgamer.com/rss/")!,
            kind: .rss,
            categories: [.gaming, .entertainment, .technology]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "138817E7-FEF1-4EE5-9F31-2AE4509A544F")!,
            name: "PlayStation Blog",
            url: URL(string: "https://blog.playstation.com/feed/")!,
            kind: .rss,
            categories: [.gaming, .entertainment, .business]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "533BD358-CFC4-4FC6-B285-91C1E254D043")!,
            name: "Polygon Gaming",
            url: URL(string: "https://www.polygon.com/feed/gaming/")!,
            kind: .rss,
            categories: [.gaming, .entertainment, .culture]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "5D41EC53-3168-4360-A72C-9C63165EFB9E")!,
            name: "Push Square",
            url: URL(string: "https://www.pushsquare.com/feeds/latest")!,
            kind: .rss,
            categories: [.gaming, .entertainment, .culture]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "47DDFA0C-A305-4F5C-8F29-9AEEFBA52BCE")!,
            name: "Rock Paper Shotgun",
            url: URL(string: "https://www.rockpapershotgun.com/feed")!,
            kind: .rss,
            categories: [.gaming, .entertainment, .culture]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "E7D13AA6-0639-46C4-9AFC-CCA922BDF9D1")!,
            name: "The Hollywood Reporter Video Games",
            url: URL(string: "https://www.hollywoodreporter.com/t/video-games/feed/")!,
            kind: .rss,
            categories: [.entertainment, .gaming, .business, .culture]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "F6AD9C8A-0DD3-428B-B312-4E26D374C089")!,
            name: "The Verge Games",
            url: URL(string: "https://www.theverge.com/rss/games/index.xml")!,
            kind: .rss,
            categories: [.gaming, .entertainment, .technology, .culture]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "A9BB8712-6AC8-4F47-96A7-655E1AAE0B8E")!,
            name: "Variety Gaming",
            url: URL(string: "https://variety.com/v/gaming/feed/")!,
            kind: .rss,
            categories: [.entertainment, .gaming, .business, .culture]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "8F26B06A-93DB-480C-BF20-FD9AE23B5449")!,
            name: "VG247",
            url: URL(string: "https://www.vg247.com/feed")!,
            kind: .rss,
            categories: [.gaming, .entertainment, .culture]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "93DEE45B-C032-4E53-B0C7-090258C46210")!,
            name: "Video Games Chronicle",
            url: URL(string: "https://www.videogameschronicle.com/feed/")!,
            kind: .rss,
            categories: [.gaming, .entertainment, .business]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "E363EF02-307A-47E0-B655-F3A9BD528198")!,
            name: "Xbox Wire",
            url: URL(string: "https://news.xbox.com/en-us/feed/")!,
            kind: .rss,
            categories: [.gaming, .entertainment, .business]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "C230D729-50F3-46FD-8D80-E70C6744F2A8")!,
            name: "OpenAI News",
            url: URL(string: "https://openai.com/news/rss.xml")!,
            kind: .rss,
            categories: [.ai, .technology, .business, .policy]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "2E72668F-F9A9-4208-96C2-4DF5D7EE9B66")!,
            name: "Google AI Blog",
            url: URL(string: "https://blog.google/technology/ai/rss/")!,
            kind: .rss,
            categories: [.ai, .technology, .business]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "CCB3FC3D-D74C-405E-B149-BE6CEF05DB3C")!,
            name: "Google DeepMind Blog",
            url: URL(string: "https://deepmind.google/blog/rss.xml")!,
            kind: .rss,
            categories: [.ai, .science, .technology]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "3FB322C8-D712-47C9-A70E-32198EF99ECB")!,
            name: "Google Research Blog",
            url: URL(string: "https://research.google/blog/rss/")!,
            kind: .rss,
            categories: [.science, .ai, .technology]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "A32510B4-B5CB-459A-9FAF-3BEA29F914B9")!,
            name: "MIT Technology Review",
            url: URL(string: "https://www.technologyreview.com/feed/")!,
            kind: .rss,
            categories: [.technology, .ai, .science, .business, .ideas]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "4D36501C-2F13-4699-A21A-96BBF940F412")!,
            name: "AWS News Blog",
            url: URL(string: "https://aws.amazon.com/blogs/aws/feed/")!,
            kind: .rss,
            categories: [.infrastructure, .technology, .business]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "3FD670DE-6503-45BD-AE11-EF32951A563D")!,
            name: "Microsoft Azure Blog",
            url: URL(string: "https://azure.microsoft.com/en-us/blog/feed/")!,
            kind: .rss,
            categories: [.infrastructure, .technology, .business]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "AD912BA2-31D0-4A52-A198-7E88101BA2E4")!,
            name: "Google Cloud Release Notes",
            url: URL(string: "https://cloud.google.com/feeds/gcp-release-notes.xml")!,
            kind: .rss,
            categories: [.infrastructure, .developer, .technology]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "E10CA796-6CE7-4729-8439-0F49E4FF8531")!,
            name: "Cloudflare Blog",
            url: URL(string: "https://blog.cloudflare.com/rss")!,
            kind: .rss,
            categories: [.infrastructure, .security, .developer, .technology]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "E6C7480A-A0BB-4F5E-AF59-F791CACCFA87")!,
            name: "Data Center Dynamics",
            url: URL(string: "https://www.datacenterdynamics.com/en/rss/")!,
            kind: .rss,
            categories: [.infrastructure, .business, .technology]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "A2AE44CF-3312-4D5F-A0F5-81CA2498ACD8")!,
            name: "The Register",
            url: URL(string: "https://api.theregister.com/api/v1/article?orderBy=published&site_id=2&remapper=rss")!,
            kind: .rss,
            categories: [.technology, .business, .infrastructure, .security]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "98D0D9C6-0576-4C25-A2CF-57E829865966")!,
            name: "InfoWorld",
            url: URL(string: "https://www.infoworld.com/feed/")!,
            kind: .rss,
            categories: [.technology, .developer, .data, .business]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "69F49D36-5F84-4065-AC7F-3463B6B93280")!,
            name: "GAIA-X",
            url: URL(string: "https://gaia-x.eu/feed/")!,
            kind: .rss,
            categories: [.infrastructure, .policy, .technology, .business]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "CF9817C6-BB70-45DA-A554-7E3C0001E2DC")!,
            name: "RIPE Labs",
            url: URL(string: "https://labs.ripe.net/feed.xml")!,
            kind: .rss,
            categories: [.infrastructure, .technology, .policy]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "8F15AF60-0EFD-4166-A5E1-B4E39F8FB29D")!,
            name: "APNIC Blog",
            url: URL(string: "https://blog.apnic.net/feed/")!,
            kind: .rss,
            categories: [.infrastructure, .technology, .policy]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "0DA5BE48-8BD2-49E9-9664-94A402558550")!,
            name: "CNCF Blog",
            url: URL(string: "https://www.cncf.io/feed/")!,
            kind: .rss,
            categories: [.infrastructure, .developer, .technology, .business]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "0DAB7EF7-818F-4E3D-A86D-4B0EB5C1F8D3")!,
            name: "GitHub Blog",
            url: URL(string: "https://github.blog/feed/")!,
            kind: .rss,
            categories: [.developer, .technology, .security, .business]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "E3FF7E9A-39AC-4515-8B8B-E7E25790B4F9")!,
            name: "The New Stack",
            url: URL(string: "https://thenewstack.io/blog/feed/")!,
            kind: .rss,
            categories: [.developer, .infrastructure, .technology, .business]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "2268CA58-5BF4-4BE5-AD29-F10D50C1B39A")!,
            name: "InfoQ",
            url: URL(string: "https://feed.infoq.com/")!,
            kind: .rss,
            categories: [.developer, .technology, .business, .ideas]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "D4ED5C13-AD35-4BEA-BD91-D35303398510")!,
            name: "CISA",
            url: URL(string: "https://www.cisa.gov/rss.xml")!,
            kind: .rss,
            categories: [.security, .policy, .technology, .world]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "411CAAE7-532A-4B12-B362-4E2202386EA4")!,
            name: "Microsoft Security Blog",
            url: URL(string: "https://www.microsoft.com/en-us/security/blog/feed/")!,
            kind: .rss,
            categories: [.security, .technology, .business]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "82C25BDF-9A99-4028-97E6-1CB8AF1D505B")!,
            name: "CrowdStrike Blog",
            url: URL(string: "https://www.crowdstrike.com/en-us/blog/feed")!,
            kind: .rss,
            categories: [.security, .technology, .business]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "72CB9117-5FC4-439D-98FB-B179B4196520")!,
            name: "Unit 42",
            url: URL(string: "https://unit42.paloaltonetworks.com/feed/")!,
            kind: .rss,
            categories: [.security, .technology, .world]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "61293334-4A3F-4A78-9DE5-1B7284EE0134")!,
            name: "Dark Reading",
            url: URL(string: "https://www.darkreading.com/rss.xml")!,
            kind: .rss,
            categories: [.security, .technology, .business]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "E1A46251-8075-4BE8-A4F3-23B34785F077")!,
            name: "The Record",
            url: URL(string: "https://therecord.media/feed")!,
            kind: .rss,
            categories: [.security, .technology, .policy, .world]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "357230B8-8FAD-4D04-9F70-BD0BA177333C")!,
            name: "NIST News",
            url: URL(string: "https://www.nist.gov/news-events/news/rss.xml")!,
            kind: .rss,
            categories: [.policy, .security, .technology, .science]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "1980B635-0026-4D25-9336-F2D880EB6F37")!,
            name: "European Data Protection Board",
            url: URL(string: "https://www.edpb.europa.eu/feed/news_en")!,
            kind: .rss,
            categories: [.policy, .security, .world, .technology]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "C1D6EA01-5FA0-46A7-820F-977ADB15D6A9")!,
            name: "European Commission",
            url: URL(string: "https://commission.europa.eu/node/2/rss_en")!,
            kind: .rss,
            categories: [.policy, .world, .business]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "D6780AEF-ED91-4E57-979A-56E00FD6D558")!,
            name: "OpenSSF",
            url: URL(string: "https://openssf.org/feed/")!,
            kind: .rss,
            categories: [.security, .developer, .technology]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "C3679654-D928-4B22-9977-53ECAAB55F17")!,
            name: "W3C Blog",
            url: URL(string: "https://www.w3.org/blog/feed/")!,
            kind: .rss,
            categories: [.developer, .policy, .technology]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "2C2FD284-546C-4287-9E5F-46992231538F")!,
            name: "IETF Blog",
            url: URL(string: "https://www.ietf.org/blog/feed/")!,
            kind: .rss,
            categories: [.infrastructure, .policy, .technology]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "09BA332B-220B-4472-823A-BBB5D5F1A1D6")!,
            name: "Federal Reserve Press Releases",
            url: URL(string: "https://www.federalreserve.gov/feeds/press_all.xml")!,
            kind: .rss,
            categories: [.finance, .business, .policy, .world]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "825FBB78-5EAE-4C36-9E02-2FE15083BDAF")!,
            name: "SEC Press Releases",
            url: URL(string: "https://www.sec.gov/news/pressreleases.rss")!,
            kind: .rss,
            categories: [.finance, .business, .policy]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "122C0876-1E2E-437F-A9DA-683896C206A4")!,
            name: "European Central Bank",
            url: URL(string: "https://www.ecb.europa.eu/rss/press.html")!,
            kind: .rss,
            categories: [.finance, .business, .policy, .world]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "A18E470F-349F-448F-8397-E6EA013C9892")!,
            name: "Stripe Blog",
            url: URL(string: "https://stripe.com/blog/feed.rss")!,
            kind: .rss,
            categories: [.finance, .developer, .business, .technology]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "7393BA7E-B9C5-4A9B-8CA6-F68F282F335A")!,
            name: "Plaid Blog",
            url: URL(string: "https://plaid.com/blog/rss.xml")!,
            kind: .rss,
            categories: [.finance, .developer, .business, .technology]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "DD829331-5FAB-4EF3-9CFA-259799F69639")!,
            name: "Payments Dive",
            url: URL(string: "https://www.paymentsdive.com/feeds/news/")!,
            kind: .rss,
            categories: [.finance, .business, .technology]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "1668DA13-E096-46A9-A3A1-4A6A28D57B71")!,
            name: "PYMNTS",
            url: URL(string: "https://www.pymnts.com/feed/")!,
            kind: .rss,
            categories: [.finance, .business, .technology]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "2ADB10F1-7C64-47E6-866F-02CB03835B5E")!,
            name: "WHO News",
            url: URL(string: "https://www.who.int/rss-feeds/news-english.xml")!,
            kind: .rss,
            categories: [.health, .science, .world, .policy]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "BE20FD62-FBCF-422E-9D47-0D22360414FC")!,
            name: "UN News",
            url: URL(string: "https://news.un.org/feed/subscribe/en/news/all/rss.xml")!,
            kind: .rss,
            categories: [.world, .policy, .climate, .health]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "7A2B8096-6D98-4FE0-9247-D92239F6C282")!,
            name: "STAT",
            url: URL(string: "https://www.statnews.com/feed/")!,
            kind: .rss,
            categories: [.health, .science, .business]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "77710C0B-22EC-4C03-8CBA-8E99A314741A")!,
            name: "Healthcare IT News",
            url: URL(string: "https://www.healthcareitnews.com/content-feed/all")!,
            kind: .rss,
            categories: [.health, .technology, .business]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "1D61B5D9-5A14-43D2-AC54-7510B5193A67")!,
            name: "Fierce Healthcare",
            url: URL(string: "https://www.fiercehealthcare.com/rss.xml")!,
            kind: .rss,
            categories: [.health, .business, .policy]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "E6F12094-048F-452F-848B-B4BDBE5FF55D")!,
            name: "Rock Health",
            url: URL(string: "https://rockhealth.com/feed/")!,
            kind: .rss,
            categories: [.health, .business, .technology]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "44B6B4AA-01E0-4335-9576-8C6DC84FF36E")!,
            name: "ACER News",
            url: URL(string: "https://www.acer.europa.eu/rss.xml")!,
            kind: .rss,
            categories: [.energy, .policy, .climate, .world]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "A77313B0-473B-438F-B149-001F67E10885")!,
            name: "Utility Dive",
            url: URL(string: "https://www.utilitydive.com/feeds/news/")!,
            kind: .rss,
            categories: [.energy, .business, .climate]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "E97E1254-8F4E-4765-9265-BE863B51C5E9")!,
            name: "Canary Media",
            url: URL(string: "https://www.canarymedia.com/rss.rss")!,
            kind: .rss,
            categories: [.energy, .climate, .business, .technology]
        ),
        PlainNewsSource(
            id: UUID(uuidString: "4E33D954-2F13-45E3-8942-FC7F6B9C8E73")!,
            name: "Hacker News",
            url: URL(string: "https://news.ycombinator.com/")!,
            kind: .web,
            categories: [.technology, .business, .science, .security, .ideas]
        )
    ]
}
