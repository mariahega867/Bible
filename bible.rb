require 'webrick'
require 'json'
require 'net/http'
require 'uri'

SCHEDULE_FILE = "schedule.json"
PROGRESS_FILE = "progress.json"

# Load the schedule
def loadSchedule
  JSON.parse(File.read(SCHEDULE_FILE))
end

# Load progress
def loadProgress
  JSON.parse(File.read(PROGRESS_FILE))
end

# Save the progress
def saveProgress(progress)
  File.write(PROGRESS_FILE, progress.to_json)
end

# Fetch Bible chapter content
def fetchBibleContent(book, chapter)
  uri = URI("https://bible-api.com/#{URI.encode_www_form_component(book)}+#{chapter}")
  response = Net::HTTP.get(uri)
  data = JSON.parse(response)
  data["text"]
rescue StandardError => e
  "Error fetching Bible content: #{e.message}"
end

# Server class
class BibleServer < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(request, response)
    if request.path == '/'
      progress = loadProgress
      schedule = loadSchedule
      day = progress["lastReadDay"]

      # Fetch daily reading
      dailyReading = schedule[day.to_s]
      book = dailyReading["book"]
      chapter = dailyReading["chapter"]
      progress_percentage = (day.to_f / 365 * 100).round(2)

      # Fetch chapter content using the Bible API
      chapter_content = fetchBibleContent(book, chapter)

      # Respond with updated HTML
      response.status = 200
      response.content_type = 'text/html'
      response.body = <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>The Bible Challenge</title>
          <style>
            body {
              font-family: Arial, sans-serif;
              background-color: #f9f9f9;
              margin: 0;
              padding: 0;
            }
            .container {
              width: 80%;
              margin: auto;
              text-align: center;
              padding: 20px;
              background: #ffffff;
              box-shadow: 0px 4px 10px rgba(0, 0, 0, 0.1);
              border-radius: 10px;
            }
            h1 {
              font-size: 2em;
              margin-bottom: 10px;
              color: #333333;
            }
            table {
              width: 100%;
              border-collapse: collapse;
              margin-bottom: 20px;
            }
            th, td {
              border: 1px solid #dddddd;
              padding: 8px;
              text-align: center;
            }
            th {
              background-color: #f4f4f4;
              color: #555555;
            }
            button {
              background-color: #28a745;
              color: white;
              padding: 10px 20px;
              border: none;
              border-radius: 5px;
              cursor: pointer;
            }
            button:hover {
              background-color: #218838;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <table>
              <tr>
                <th>Book</th>
                <th>Chapter</th>
                <th>Progress</th>
              </tr>
              <tr>
                <td>#{book}</td>
                <td>#{chapter}</td>
                <td>#{progress_percentage}%</td>
              </tr>
            </table>
            <h2>Today's Reading</h2>
            <p>#{chapter_content}</p>
            <form action='/mark_done' method='post'>
              <button type='submit'>Mark as Done</button>
            </form>
          </div>
        </body>
        </html>
      HTML
    else
      response.status = 404
      response.content_type = 'text/plain'
      response.body = "Page not found"
    end
  end

  def do_POST(request, response)
    if request.path == '/mark_done'
      progress = loadProgress

      # Increment lastReadDay
      progress["lastReadDay"] += 1

      # Save updated progress
      saveProgress(progress)

      # Redirect to root
      response.status = 302
      response['Location'] = '/'
    else
      response.status = 404
      response.content_type = 'text/plain'
      response.body = "Page not found"
    end
  end
end

# Start the server
server = WEBrick::HTTPServer.new(Port: 8080)
server.mount "/", BibleServer

trap 'INT' do
  server.shutdown
end

server.start


#website link http://localhost:8080