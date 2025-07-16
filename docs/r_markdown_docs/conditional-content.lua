function Div(el)
    if el.attributes['show-in'] then
      if FORMAT:match 'latex' then
        if el.attributes['show-in'] == "html" then
          el.content = ""
          return el
        end
      elseif FORMAT:match 'html' then
        if el.attributes['show-in'] == 'pdf' then
          el.content = ""
          return el
        end
      end
    end
  end  