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

          <title>Bible Reading Progress Board</title>

          <style>
          
            body {
              font-family: Arial, sans-serif;
              text-align: center;
              background-color: #f9f7e8;
              margin: 0;
              padding: 0;
            }

            .header {
              background-color: #ffcccb;
              padding: 20px;
            }

            h1 {
              margin: 0;
              color: #4e2166;
              font-size: 2em;
            }

            .board {
              display: grid;
              grid-template-columns: repeat(10, 1fr);
              gap: 10px;
              padding: 20px;
              max-width: 80%;
              margin: 0 auto;
            }

            .circle {
              width: 80px;
              height: 80px;
              background-color: #ffd1dc;
              border: 3px solid #4e2166;
              border-radius: 50%;
              display: flex;
              align-items: center;
              justify-content: center;
              font-size: 16px;
              color: #4e2166;
              font-weight: bold;
              text-align: center;
            }


            .circle.completed {
              background-color: #6eccaf;
              color: white;
            }


            .footer {
              background-color: #4e2166;
              color: #fff;
              padding: 10px;
              position: fixed;
              bottom: 0;
              width: 100%;
            }


            a {
              text-decoration: none;
            }


          </style>

        </head>

        <body>

          <div class="header">
            <h1>Bible Reading Progress Board</h1>
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
                background-color: #f9f7e8;
                margin: 0;
                padding: 0;
              }

              .header {
                background-color: #ffcccb;
                padding: 20px;
              }

              h1 {
                margin: 0;
                color: #4e2166;
                font-size: 2em;
              }

              .reading {
                padding: 20px;
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
                padding: 10px 20px;
                font-size: 16px;
                background-color: #4e2166;
                color: #fff;
                border: none;
                border-radius: 5px;
                cursor: pointer;
                margin-top: 20px;
              }

              button:hover {
                background-color: #6eccaf;
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
            </div>


            <form action="/mark_done/#{day}" method="post">
              <button type="submit">Mark Done</button>
            </form>


            <div class="footer">
              <p>Progress: #{progress["lastReadDay"]}/365 days completed</p>
            </div>


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