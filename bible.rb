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

# Use API to get the reading
def fetchBibleContent(book, chapter)
  uri = URI("https://bible-api.com/#{URI.encode_www_form_component(book)}+#{chapter}")
  response = Net::HTTP.get(uri)
  data = JSON.parse(response)
  data["text"]
rescue StandardError => e
  "Error getting Bible content: #{e.message}"
end

# Server class
class BibleServer < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(request, response)

    progress = loadProgress
    schedule = loadSchedule

    last_read_day = progress["lastReadDay"]
  
    if request.path == '/'

      # Create the board
      board_html = ""

      (1..365).each do |day|

        completed_class = day <= last_read_day ? "completed" : ""

        board_html += "<a href='/day/#{day}'><div class='circle #{completed_class}'>Day #{day}</div></a>"

      end
  
      # Respond with the main board
      response.status = 200
      response.content_type = 'text/html'

      response.body = <<~HTML

        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">

          <meta name="viewport" content="width=device-width, initial-scale=1.0">

          <title>Daily Bible Reading Progress Board</title>

          <style>
          
            body {
              font-family: Arial, sans-serif;
              text-align: center;
              background-color: #f3f4f6;
              margin: 0;
              padding: 0;
              color: #333;
            }

            .header {
              background-color: #4a90e2;
              padding: 20px;
              color: white;
              box-shadow: 0px 4px 6px rgba(0, 0, 0, 0.1);
            }

            h1 {
              margin: 0;
              font-size: 2em;
            }

            .board {
              max-height: 80vh;
              overflow-y: auto;
              display: grid;
              grid-template-columns: repeat(10, 1fr);
              gap: 15px;
              padding: 20px;
              max-width: 90%;
              margin: 0 auto;
            }

            .circle {
              width: 80px;
              height: 80px;
              background-color: #ffffff;
              border: 3px solid #4a90e2;
              border-radius: 30%;
              display: flex;
              align-items: center;
              justify-content: center;
              font-size: 14px;
              color: #4a90e2;
              text-align: center;
              transition: transform 0.2s ease, background-color 0.3s ease; 
              box-shadow: 0px 4px 6px rgba(0, 0, 0, 0.1);
            }

            .circle:hover {
             transform: scale(1.1); 
             background-color: #e1ecf8; 
            }


            .circle.completed {
              background-color: #2ecc71;
              color: white;
              board: none;
            }


            .footer {
              background-color: #4a90e2;
              color: #fff;
              padding: 15px;
              position: fixed;
              bottom: 0;
              width: 100%;
              text-align: center;
              font-size: 14px;
              box-shadow: 0px -4px 6px rgba(0, 0, 0, 0.1); 
            }


            a {
              text-decoration: none;
            }


          </style>

        </head>

        <body>

          <div class="header">
            <h1>Progress Board</h1>
          </div>


          <div class="board">
            #{board_html}
          </div>

          <div class="footer">
            <p>Progress: #{last_read_day}/365 days completed (#{(last_read_day.to_f / 365 * 100).round(1)}%)</p>
          </div>


        </body>

        </html>
      HTML
  
    elsif request.path.match(%r{^/day/(\d+)$})

      # Show reading of the day
      day = request.path.match(%r{^/day/(\d+)$})[1].to_i

      if day > 0 && day <= 365

        daily_reading = schedule[day.to_s]

        book = daily_reading["book"]
        chapter = daily_reading["chapter"]
        video_url = daily_reading["video"]

        chapter_content = fetchBibleContent(book, chapter)
  
        # New page to show the reading
        response.status = 200

        response.content_type = 'text/html'

        response.body = <<~HTML
          <!DOCTYPE html>
          <html>

          <head>

            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">

            <title>Day #{day} Reading</title>

            <style>

            body {
              font-family: Arial, sans-serif;
              text-align: center;
              background-color: #f3f4f6;
              margin: 0;
              padding: 0;
              color: #333;
            }

            .header {
              background-color: #4a90e2;
              padding: 20px;
              color: white;
              box-shadow: 0px 4px 6px rgba(0, 0, 0, 0.1);
            }

            h1 {
              margin: 0;
              font-size: 2em;
            }

              .reading {
                padding: 20px;
                margin: 0 auto;
                max-width: 700px; 
                line-height: 1.6; 
                word-wrap: break-word; 
                overflow-wrap: break-word; 
                font-size: 16px;
                color: #333;

              }

              pre {
              white-space: pre-wrap; 
              word-wrap: break-word; 
              color: #444;

              }

              .footer {
                background-color: #4e2166;
                color: #fff;
                padding: 10px;
                position: fixed;
                bottom: 0;
                width: 100%;
              }

              button {
              padding: 12px 25px;
              font-size: 16px;
              font-weight: 600;
              background: linear-gradient(to right, #4a90e2, #6bb8f5); 
              color: white;
              border: none;
              border-radius: 25px; 
              cursor: pointer;
              box-shadow: 0px 4px 6px rgba(0, 0, 0, 0.1); 
              transition: background 0.3s ease, transform 0.2s ease;
            }

              button:hover {
                background: linear-gradient(to right, #2e77d0, #5aaef2); 
                transform: scale(1.05);
              }

              iframe {
              width: 100%;
              height: 315px;
              margin-top: 20px;
            }

            </style>

          </head>

          <body>

            <div class="header">
              <h1>Day #{day}: #{book} #{chapter}</h1>
            </div>


            <div class="reading">
              <p><strong>Today's Reading:</strong></p>
              <pre>#{chapter_content}</pre>

               <iframe 
          src="#{video_url}" 
          title="YouTube video player" 
          frameborder="0"
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" 
          allowfullscreen>
        </iframe>

            </div>


            <form action="/mark_done/#{day}" method="post">
              <button type="submit">Mark Done</button>
            </form>


          </body>

          </html>
        HTML


      else
        response.status = 404
        response.content_type = 'text/plain'
        response.body = "Invalid day"
      end


    else
      response.status = 404
      response.content_type = 'text/plain'
      response.body = "Page not found"
    end


  end
  
  

  def do_POST(request, response)
    if request.path.match(%r{^/mark_done/(\d+)$})

      day = request.path.match(%r{^/mark_done/(\d+)$})[1].to_i
      progress = loadProgress
  
      # Update progress if user clicks "Mark Done"
      if day == progress["lastReadDay"] + 1
        progress["lastReadDay"] = day
        saveProgress(progress)
      end
  

      # Go back to the board
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