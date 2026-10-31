-- The mobile lounge summary reads these denormalized columns. Keep them in
-- sync with the same lounge_reviews rows shown in the reviews section.
CREATE OR REPLACE FUNCTION public.update_lounge_average_rating()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  affected_lounge_id uuid;
BEGIN
  FOR affected_lounge_id IN
    SELECT DISTINCT lounge_id
    FROM (VALUES
      (CASE WHEN TG_OP = 'DELETE' THEN OLD.lounge_id ELSE NEW.lounge_id END),
      (CASE WHEN TG_OP = 'UPDATE' THEN OLD.lounge_id ELSE NULL::uuid END)
    ) AS affected(lounge_id)
    WHERE lounge_id IS NOT NULL
    ORDER BY lounge_id
  LOOP
    -- Serialize concurrent review changes before reading their aggregate.
    PERFORM 1 FROM public.lounges WHERE id = affected_lounge_id FOR UPDATE;
    UPDATE public.lounges AS lounge
    SET total_reviews = review_summary.review_count,
        rating = review_summary.average_rating
    FROM (
      SELECT count(*)::integer AS review_count,
             coalesce(avg(rating), 0) AS average_rating
      FROM public.lounge_reviews
      WHERE lounge_id = affected_lounge_id
    ) AS review_summary
    WHERE lounge.id = affected_lounge_id;
  END LOOP;

  RETURN NULL;
END;
$function$;

DROP TRIGGER IF EXISTS trg_update_lounge_rating ON public.lounge_reviews;
CREATE TRIGGER trg_update_lounge_rating
AFTER INSERT OR UPDATE OR DELETE ON public.lounge_reviews
FOR EACH ROW EXECUTE FUNCTION public.update_lounge_average_rating();

-- Existing counts included stale and demo values with no matching reviews.
-- Rebuild the displayed summary from the authoritative review records.
UPDATE public.lounges AS lounge
SET total_reviews = review_summary.review_count,
    rating = review_summary.average_rating
FROM (
  SELECT lounge.id,
         count(review.id)::integer AS review_count,
         coalesce(avg(review.rating), 0) AS average_rating
  FROM public.lounges AS lounge
  LEFT JOIN public.lounge_reviews AS review ON review.lounge_id = lounge.id
  GROUP BY lounge.id
) AS review_summary
WHERE lounge.id = review_summary.id
  AND (lounge.total_reviews IS DISTINCT FROM review_summary.review_count
       OR lounge.rating IS DISTINCT FROM review_summary.average_rating);
